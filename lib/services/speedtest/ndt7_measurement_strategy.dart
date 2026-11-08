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

/// Shared plumbing for server-side trackers: records client byte accounting
/// and exposes a post-warm-up client average as a fallback estimate.
abstract class _ServerTrackerBase implements Ndt7ThroughputTracker {
  _ServerTrackerBase({
    required Ndt7PlatformSettings settings,
    required bool useClientFallback,
  })  : _settings = settings,
        _useClientFallback = useClientFallback;

  final Ndt7PlatformSettings _settings;
  final bool _useClientFallback;
  bool _warmupDone = false;
  int _lastClientTotalBytes = 0;
  Duration _lastClientElapsed = Duration.zero;
  int? _clientBytesAtWarmupEnd;
  Duration? _elapsedAtWarmupEnd;

  @override
  void onClientBytes(int totalBytes, Duration testElapsed) {
    _lastClientTotalBytes = totalBytes;
    _lastClientElapsed = testElapsed;
    _markWarmupDone(testElapsed);
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
    // Anchor the client fallback at the warm-up end so ramp-up bytes are
    // excluded from the fallback estimate.
    _clientBytesAtWarmupEnd = _lastClientTotalBytes;
    _elapsedAtWarmupEnd = testElapsed;
  }
}

/// Shared tracker that derives throughput from server TCPInfo deltas after
/// the platform warm-up window, optionally preferring AppInfo goodput and
/// optionally falling back to client-side post-warm-up byte accounting when
/// the server reports nothing usable.
///
/// This is the mobile methodology: on Android every client-visible measure
/// (client-side median, server cumulative) undershot the reference tools,
/// while windowed deltas tracked the wire rate (27 Mbps vs Fing's 26.4 on a
/// hotspot). Upload additionally must never fall back to client bytes:
/// mobile stacks buffer aggressively, so bytes-pushed-to-socket measures
/// buffer fill, not the wire (239.8 Mbps reported vs 26.4 actual).
class ServerDeltaTracker extends _ServerTrackerBase {
  ServerDeltaTracker({
    required Ndt7PlatformSettings settings,
    required this.direction,
    required bool useClientFallback,
    bool preferAppInfo = false,
    this.sampleWindowSize = 5,
  })  : _counterIsSent = direction == Ndt7Direction.download,
        _preferAppInfo = preferAppInfo,
        _accumulator =
            DeltaWindowAccumulator(minWindowUs: settings.minSampleWindowUs),
        super(settings: settings, useClientFallback: useClientFallback);

  final Ndt7Direction direction;
  final bool _counterIsSent;
  final bool _preferAppInfo;
  final DeltaWindowAccumulator _accumulator;
  final int sampleWindowSize;

  final List<double> _recentSamplesMbps = [];

  @override
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed) {
    _markWarmupDone(testElapsed);
    if (!_warmupDone) return;

    // AppInfo carries application-level goodput (payload only), which is the
    // most accurate signal when the server provides it.
    if (_preferAppInfo && measurement.throughputMbps != null) {
      _recentSamplesMbps.add(measurement.throughputMbps!);
      if (_recentSamplesMbps.length > sampleWindowSize) {
        _recentSamplesMbps.removeAt(0);
      }
      return;
    }

    final bytes =
        _counterIsSent ? measurement.bytesSent : measurement.bytesReceived;
    final elapsedUs = measurement.elapsedTimeUs;
    if (bytes == null || elapsedUs == null) return;

    final windowMbps = _accumulator.feed(bytes, elapsedUs);
    if (windowMbps != null) {
      _recentSamplesMbps.add(windowMbps);
      if (_recentSamplesMbps.length > sampleWindowSize) {
        _recentSamplesMbps.removeAt(0);
      }
    }
  }

  @override
  void _markWarmupDone(Duration testElapsed) {
    final wasDone = _warmupDone;
    super._markWarmupDone(testElapsed);
    if (wasDone || !_warmupDone) return;
    // Anchor the delta window at the warm-up end so ramp-up samples are
    // excluded from the instantaneous estimate.
    _accumulator.reset();
  }

  @override
  double? get throughputMbps {
    if (_recentSamplesMbps.isEmpty) return _clientFallbackMbps();
    final sorted = List<double>.from(_recentSamplesMbps)..sort();
    final mid = sorted.length ~/ 2;
    final median =
        sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    return median;
  }
}

/// Client-side receiver tracker for desktop download: collects post-warm-up
/// cumulative transfer-rate samples from bytes the client received and
/// reports their median.
///
/// This is the measurement the macOS app shipped with originally, and the
/// only download methodology observed to match the M-Lab web client on a
/// desktop connection (223 Mbps vs M-Lab's 223). Server TCPInfo.BytesSent is
/// deliberately ignored for throughput here: on fast desktop links it runs
/// far above the delivered rate (292-462 Mbps observed vs ~223 real) because
/// the sender's counter includes in-flight data.
class ClientSamplesTracker implements Ndt7ThroughputTracker {
  ClientSamplesTracker({required Ndt7PlatformSettings settings})
      : _warmupDuration = settings.warmupDuration;

  final Duration _warmupDuration;

  /// Samples kept sorted so the median is an O(1) read at progress cadence.
  final List<double> _sortedSamplesMbps = [];

  @override
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed) {
    // Server messages still carry minRTT / retransmission data, which the
    // service aggregates; throughput comes exclusively from client bytes.
  }

  @override
  void onClientBytes(int totalBytes, Duration testElapsed) {
    if (testElapsed <= _warmupDuration) return;
    final seconds = testElapsed.inMicroseconds / 1e6;
    if (seconds <= 0) return;
    final sample = 8 * totalBytes / seconds / 1e6;
    var lo = 0;
    var hi = _sortedSamplesMbps.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_sortedSamplesMbps[mid] < sample) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _sortedSamplesMbps.insert(lo, sample);
  }

  @override
  double? get throughputMbps {
    final count = _sortedSamplesMbps.length;
    if (count == 0) return null;
    final mid = count ~/ 2;
    if (count.isOdd) return _sortedSamplesMbps[mid];
    return (_sortedSamplesMbps[mid - 1] + _sortedSamplesMbps[mid]) / 2;
  }
}

/// Client-side delta tracker for mobile download: measures bytes received
/// since last sample and reports instantaneous throughput median.
///
/// Unlike [ClientSamplesTracker] which uses cumulative averages (dragged down
/// by slow ramp-up on mobile), this tracks deltas to capture the true wire
/// rate after TCP congestion control stabilizes.
class ClientDeltaTracker implements Ndt7ThroughputTracker {
  ClientDeltaTracker({required Ndt7PlatformSettings settings})
      : _warmupDuration = settings.warmupDuration;

  final Duration _warmupDuration;
  int _lastBytes = 0;
  Duration _lastElapsed = Duration.zero;
  final List<double> _sortedSamplesMbps = [];

  @override
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed) {
    // Server messages carry minRTT / retransmission data only.
  }

  @override
  void onClientBytes(int totalBytes, Duration testElapsed) {
    if (testElapsed <= _warmupDuration) {
      _lastBytes = totalBytes;
      _lastElapsed = testElapsed;
      return;
    }

    final deltaBytes = totalBytes - _lastBytes;
    final deltaUs = testElapsed.inMicroseconds - _lastElapsed.inMicroseconds;

    if (deltaUs <= 0 || deltaBytes < 0) return;

    final mbps = 8 * deltaBytes / (deltaUs / 1e6) / 1e6;
    _lastBytes = totalBytes;
    _lastElapsed = testElapsed;

    // Insert into sorted list for median calculation.
    var lo = 0;
    var hi = _sortedSamplesMbps.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_sortedSamplesMbps[mid] < mbps) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _sortedSamplesMbps.insert(lo, mbps);
  }

  @override
  double? get throughputMbps {
    final count = _sortedSamplesMbps.length;
    if (count == 0) return null;
    final mid = count ~/ 2;
    if (count.isOdd) return _sortedSamplesMbps[mid];
    return (_sortedSamplesMbps[mid - 1] + _sortedSamplesMbps[mid]) / 2;
  }
}

/// Receiver-side cumulative tracker for desktop upload: uses the latest
/// server sample as 8 * BytesReceived / ElapsedTime, preferring AppInfo
/// goodput when the server provides it, with a post-warm-up client average
/// as a last-resort fallback.
///
/// This is the macOS app's original upload path and the closest observed
/// reading to the plan rate (177 Mbps vs ~150 expected). Delta windowing
/// overshoots further on desktop because it discards the ramp-up bytes a
/// cumulative average absorbs.
class ServerCumulativeTracker extends _ServerTrackerBase {
  ServerCumulativeTracker({
    required Ndt7PlatformSettings settings,
    required this.direction,
    required bool useClientFallback,
    bool preferAppInfo = true,
  })  : _counterIsSent = direction == Ndt7Direction.download,
        _preferAppInfo = preferAppInfo,
        super(settings: settings, useClientFallback: useClientFallback);

  final Ndt7Direction direction;
  final bool _counterIsSent;
  final bool _preferAppInfo;

  double? _latestServerMbps;

  @override
  void onServerMeasurement(Ndt7Measurement measurement, Duration testElapsed) {
    _markWarmupDone(testElapsed);

    if (_preferAppInfo && measurement.throughputMbps != null) {
      _latestServerMbps = measurement.throughputMbps;
      return;
    }

    final bytes =
        _counterIsSent ? measurement.bytesSent : measurement.bytesReceived;
    final elapsedUs = measurement.elapsedTimeUs;
    if (bytes == null || elapsedUs == null || elapsedUs <= 0) return;
    _latestServerMbps = 8 * bytes / (elapsedUs / 1e6) / 1e6;
  }

  @override
  double? get throughputMbps {
    final server = _latestServerMbps;
    if (server != null) return server;
    return _clientFallbackMbps();
  }
}
