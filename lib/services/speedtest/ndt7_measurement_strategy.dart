import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Direction of a test relative to the client.
enum Ndt7Direction { download, upload }

/// Converts cumulative TCPInfo counters into windowed instantaneous
/// throughput. Samples arriving within [minWindowUs] of the anchor are
/// accumulated into the same window, so bursty or very frequent TCPInfo
/// delivery still yields stable deltas.
class DeltaWindowAccumulator {
  DeltaWindowAccumulator({required int minWindowUs})
      : _minWindowUs = minWindowUs;

  final int _minWindowUs;
  int? _anchorBytes;
  int? _anchorTimeUs;

  /// Feeds a cumulative (bytes, elapsedUs) sample. Returns the instantaneous
  /// Mbps for the completed window, or null while the window is still filling.
  double? feed(int bytes, int elapsedUs) {
    final anchorBytes = _anchorBytes;
    final anchorTimeUs = _anchorTimeUs;
    if (anchorBytes == null || anchorTimeUs == null) {
      _anchorBytes = bytes;
      _anchorTimeUs = elapsedUs;
      return null;
    }
    final deltaBytes = bytes - anchorBytes;
    final deltaTimeUs = elapsedUs - anchorTimeUs;
    if (deltaTimeUs < _minWindowUs || deltaTimeUs <= 0) {
      return null;
    }
    final mbps = 8 * deltaBytes / (deltaTimeUs / 1e6) / 1e6;
    _anchorBytes = bytes;
    _anchorTimeUs = elapsedUs;
    return mbps;
  }

  void reset() {
    _anchorBytes = null;
    _anchorTimeUs = null;
  }
}

/// Tracks the throughput estimate for one direction of an NDT7 test.
abstract class Ndt7ThroughputTracker {
  /// Feeds a parsed server measurement message (TCPInfo / AppInfo).
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed);

  /// Feeds client-side byte accounting (cumulative bytes transferred and
  /// elapsed time since the test started).
  void onClientBytes(int totalBytes, Duration testElapsed);

  /// Current best throughput estimate in Mbps; null when nothing measurable
  /// has arrived yet.
  double? get throughputMbps;
}

/// Chooses the trackers used for a speed test. Platform-specific
/// implementations live in `ndt7_mobile_strategy.dart` and
/// `ndt7_desktop_strategy.dart`; the shared state machines they compose live
/// here.
abstract class Ndt7Strategy {
  String get label;

  Ndt7ThroughputTracker createDownloadTracker(
    Ndt7PlatformSettings settings,
  );

  Ndt7ThroughputTracker createUploadTracker(
    Ndt7PlatformSettings settings,
  );
}

/// Shared tracker that derives throughput from server TCPInfo deltas after
/// the platform warm-up window, optionally preferring AppInfo goodput and
/// optionally falling back to client-side post-warm-up byte accounting when
/// the server reports nothing usable.
class ServerDeltaTracker implements Ndt7ThroughputTracker {
  ServerDeltaTracker({
    required Ndt7PlatformSettings settings,
    required this.direction,
    required bool useClientFallback,
    bool preferAppInfo = false,
  })  : _settings = settings,
        _counterIsSent = direction == Ndt7Direction.download,
        _useClientFallback = useClientFallback,
        _preferAppInfo = preferAppInfo,
        _accumulator =
            DeltaWindowAccumulator(minWindowUs: settings.minSampleWindowUs);

  final Ndt7Direction direction;
  final Ndt7PlatformSettings _settings;
  final bool _counterIsSent;
  final bool _useClientFallback;
  final bool _preferAppInfo;
  final DeltaWindowAccumulator _accumulator;

  double? _serverThroughputMbps;
  bool _warmupDone = false;
  int _lastClientTotalBytes = 0;
  Duration _lastClientElapsed = Duration.zero;
  int? _clientBytesAtWarmupEnd;
  Duration? _elapsedAtWarmupEnd;

  @override
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed) {
    _markWarmupDone(testElapsed);
    if (!_warmupDone) return;

    // AppInfo carries application-level goodput (payload only), which is the
    // most accurate signal when the server provides it.
    if (_preferAppInfo && measurement.throughputMbps != null) {
      _serverThroughputMbps = measurement.throughputMbps;
      return;
    }

    final bytes =
        _counterIsSent ? measurement.bytesSent : measurement.bytesReceived;
    final elapsedUs = measurement.elapsedTimeUs;
    if (bytes == null || elapsedUs == null) return;

    final windowMbps = _accumulator.feed(bytes, elapsedUs);
    if (windowMbps != null) {
      _serverThroughputMbps = windowMbps;
      print('Ndt7Service ${direction.name} (server-delta): '
          'bytes=$bytes, elapsedUs=$elapsedUs, ${windowMbps.toStringAsFixed(1)} Mbps');
    }
  }

  @override
  void onClientBytes(int totalBytes, Duration testElapsed) {
    _lastClientTotalBytes = totalBytes;
    _lastClientElapsed = testElapsed;
    _markWarmupDone(testElapsed);
  }

  @override
  double? get throughputMbps {
    final server = _serverThroughputMbps;
    if (server != null) return server;
    return _clientFallbackMbps();
  }

  /// Average transfer rate over the post-warm-up period, so TCP slow-start
  /// does not drag the fallback estimate down.
  double? _clientFallbackMbps() {
    if (!_useClientFallback ||
        !_warmupDone ||
        _clientBytesAtWarmupEnd == null ||
        _elapsedAtWarmupEnd == null) {
      return null;
    }
    final deltaBytes = _lastClientTotalBytes - _clientBytesAtWarmupEnd!;
    final deltaUs =
        _lastClientElapsed.inMicroseconds - _elapsedAtWarmupEnd!.inMicroseconds;
    if (deltaUs <= 0 || deltaBytes < 0) return null;
    return 8 * deltaBytes / (deltaUs / 1e6) / 1e6;
  }

  void _markWarmupDone(Duration testElapsed) {
    if (_warmupDone || testElapsed < _settings.warmupDuration) return;
    _warmupDone = true;
    // Anchor the delta window and the client fallback at the warm-up end so
    // ramp-up bytes are excluded from both.
    _accumulator.reset();
    _clientBytesAtWarmupEnd = _lastClientTotalBytes;
    _elapsedAtWarmupEnd = testElapsed;
  }
}
