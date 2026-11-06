import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:vernet/models/ndt7_result.dart';

import 'package:vernet/services/speedtest/ndt7_desktop_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_mobile_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Service for M-Lab NDT7 speed test protocol.
///
/// Uses the Locate v2 API for server discovery and implements the NDT7
/// WebSocket protocol for accurate throughput, latency, and packet loss
/// measurements. Connection handling and protocol parsing are shared across
/// platforms; throughput measurement strategy and test settings are selected
/// per platform (mobile vs desktop) at construction time.
@injectable
class Ndt7Service {
  Ndt7Service()
      : _settings = Ndt7PlatformSettings.resolve(),
        _strategy = _strategyFor(Ndt7PlatformSettings.resolve()),
        _httpClient = http.Client(),
        _webSocketFactory = _defaultWebSocketFactory;

  Ndt7Service.withDependencies({
    required http.Client httpClient,
    required WebSocketFactory webSocketFactory,
    Ndt7PlatformSettings? platformSettings,
    Ndt7Strategy? strategy,
  })  : _settings = platformSettings ?? Ndt7PlatformSettings.resolve(),
        _strategy = strategy ??
            _strategyFor(platformSettings ?? Ndt7PlatformSettings.resolve()),
        _httpClient = httpClient,
        _webSocketFactory = webSocketFactory;

  static Ndt7Strategy _strategyFor(Ndt7PlatformSettings settings) =>
      settings.isMobile
          ? const MobileNdt7Strategy()
          : const DesktopNdt7Strategy();

  final http.Client _httpClient;
  final WebSocketFactory _webSocketFactory;
  final Ndt7PlatformSettings _settings;
  final Ndt7Strategy _strategy;

  static const _locateApiUrl =
      'https://locate.measurementlab.net/v2/nearest/ndt/ndt7';
  static const _ndt7Subprotocol = 'net.measurementlab.ndt.v7';

  Timer? _activeTimer;
  WebSocket? _activeWebSocket;

  /// Discovers nearest M-Lab servers using the Locate v2 API.
  Future<List<Ndt7Server>> discoverServers() async {
    try {
      final response = await _httpClient.get(
        Uri.parse(_locateApiUrl),
        headers: {'User-Agent': 'Vernet/1.0'},
      );

      if (response.statusCode != 200) {
        throw Ndt7Exception(
          'Locate API returned status ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      if (results.isEmpty) {
        throw const Ndt7Exception('No M-Lab servers available');
      }

      final servers = results
          .map((r) => Ndt7Server.fromJson(r as Map<String, dynamic>))
          .where((s) => s.urls.downloadUrl != null && s.urls.uploadUrl != null)
          .toList();

      // Log the first server's URLs for debugging
      if (servers.isNotEmpty) {
        print(
            'Ndt7Service discoverServers: first server download URL: ${servers.first.urls.downloadUrl}');
        print(
            'Ndt7Service discoverServers: first server upload URL: ${servers.first.urls.uploadUrl}');
      }

      return servers;
    } on SocketException catch (e) {
      throw Ndt7Exception('Network error: ${e.message}', null, e);
    } on FormatException catch (e) {
      throw Ndt7Exception('Invalid Locate API response', null, e);
    }
  }

  /// Runs a complete NDT7 speed test (download + upload).
  ///
  /// Returns an [Ndt7TestResult] with throughput, latency, and packet loss
  /// metrics. Progress updates are streamed via [onProgress].
  Future<Ndt7TestResult> runTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    // Reset any leftover state from previous tests
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeWebSocket?.close();
    _activeWebSocket = null;

    final downloadResult = await runDownloadTest(
      server,
      onProgress: onProgress,
    );
    final uploadResult = await runUploadTest(
      server,
      onProgress: onProgress,
    );

    return Ndt7TestResult(
      downloadMbps: downloadResult.throughputMbps ?? 0,
      uploadMbps: uploadResult.throughputMbps ?? 0,
      latencyMs: downloadResult.minRTT ?? uploadResult.minRTT ?? 0,
      server: server,
      minRTT: downloadResult.minRTT ?? uploadResult.minRTT,
      retransmissions:
          downloadResult.retransmissions ?? uploadResult.retransmissions,
      timestamp: DateTime.now(),
    );
  }

  /// Runs download test only.
  Future<Ndt7Measurement> runDownloadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    // Reset any leftover state from previous tests
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeWebSocket?.close();
    _activeWebSocket = null;

    final url = server.urls.downloadUrl!;
    print('Ndt7Service runDownloadTest: connecting to URL: $url');
    final ws = await _connectWebSocket(url);

    try {
      return await _measureDownload(ws, onProgress: onProgress);
    } finally {
      await ws.close();
    }
  }

  /// Runs upload test only.
  Future<Ndt7Measurement> runUploadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    // Reset any leftover state from previous tests
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeWebSocket?.close();
    _activeWebSocket = null;

    final url = server.urls.uploadUrl!;
    print('Ndt7Service runUploadTest: connecting to URL: $url');
    final ws = await _connectWebSocket(url);

    try {
      return await _measureUpload(ws, onProgress: onProgress);
    } finally {
      await ws.close();
    }
  }

  Future<WebSocket> _connectWebSocket(String url) async {
    final completer = Completer<WebSocket>();
    Timer? timer;

    try {
      timer = Timer(_settings.connectionTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception(
              'WebSocket connection timed out after ${_settings.connectionTimeout.inSeconds}s',
            ),
          );
        }
      });

      final ws = await _webSocketFactory(
        url,
        protocols: [_ndt7Subprotocol],
      );

      if (!completer.isCompleted) {
        timer.cancel();
        completer.complete(ws);
      } else {
        // Timeout already fired — close the late connection.
        await ws.close();
      }
    } on WebSocketException catch (e) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          Ndt7Exception('WebSocket connection failed: ${e.message}', null, e),
        );
      }
    } on SocketException catch (e) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          Ndt7Exception('Network error: ${e.message}', null, e),
        );
      }
    } catch (e) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          Ndt7Exception('WebSocket connection failed: $e', null, e),
        );
      }
    }

    return await completer.future;
  }

  Future<Ndt7Measurement> _measureDownload(
    WebSocket ws, {
    void Function(Ndt7Progress)? onProgress,
  }) {
    _activeWebSocket = ws;
    final startTime = DateTime.now();
    var totalBytes = 0;
    double? minRTT;
    int? retransmissions;
    double? retransmissionPercentage;
    final tracker = _strategy.createDownloadTracker(_settings);

    final completer = Completer<Ndt7Measurement>();
    _activeTimer = Timer(_settings.downloadTestDuration, () {
      _activeTimer = null;
      if (!completer.isCompleted) {
        final finalThroughput = tracker.throughputMbps ?? 0.0;
        print(
            'Ndt7Service download timer complete: throughput=$finalThroughput Mbps (${_strategy.label})');
        completer.complete(Ndt7Measurement(
          throughputMbps: finalThroughput,
          minRTT: minRTT,
          retransmissions: retransmissions,
          retransmissionPercentage: retransmissionPercentage,
        ));
      }
    });

    ws.listen(
      (message) {
        if (message is List<int>) {
          totalBytes += message.length;
          final elapsed = DateTime.now().difference(startTime);
          tracker.onClientBytes(totalBytes, elapsed);

          // Skip warm-up period for progress reporting
          if (elapsed > _settings.warmupDuration) {
            final progressSpeed = tracker.throughputMbps ??
                _calculateThroughput(totalBytes, elapsed);

            onProgress?.call(Ndt7Progress(
              elapsed: elapsed.inMilliseconds / 1000.0,
              speed: progressSpeed,
              bytesTransferred: totalBytes,
              isDownload: true,
            ));
          }
        } else if (message is String) {
          final measurement = _parseNdt7Message(message);
          if (measurement != null) {
            if (measurement.minRTT != null) {
              minRTT = minRTT == null
                  ? measurement.minRTT
                  : (measurement.minRTT! < minRTT!
                      ? measurement.minRTT
                      : minRTT);
            }
            if (measurement.retransmissions != null) {
              retransmissions = retransmissions == null
                  ? measurement.retransmissions
                  : (measurement.retransmissions! > retransmissions!
                      ? measurement.retransmissions
                      : retransmissions);
            }
            if (measurement.retransmissionPercentage != null) {
              retransmissionPercentage = measurement.retransmissionPercentage;
            }
            tracker.onServerMeasurement(
              measurement,
              DateTime.now().difference(startTime),
            );
          }
        }
      },
      onError: (error) {
        _activeTimer?.cancel();
        _activeTimer = null;
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception('Download test failed: $error', null, error),
          );
        }
      },
      onDone: () {
        _activeTimer?.cancel();
        _activeTimer = null;
        if (!completer.isCompleted) {
          final elapsed = DateTime.now().difference(startTime);
          final clientThroughputMbps =
              _calculateThroughput(totalBytes, elapsed);
          final finalThroughput =
              tracker.throughputMbps ?? clientThroughputMbps;
          print(
              'Ndt7Service download test complete. trackerThroughput: ${tracker.throughputMbps}, clientThroughput: $clientThroughputMbps, final: $finalThroughput');
          completer.complete(Ndt7Measurement(
            throughputMbps: finalThroughput,
            minRTT: minRTT,
            retransmissions: retransmissions,
            retransmissionPercentage: retransmissionPercentage,
          ));
        }
      },
    );

    return completer.future;
  }

  Future<Ndt7Measurement> _measureUpload(
    WebSocket ws, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    _activeWebSocket = ws;
    final startTime = DateTime.now();
    var totalBytes = 0;
    double? minRTT;
    int? retransmissions;
    double? retransmissionPercentage;
    // Upload throughput is measured at the receiver (the server) from
    // TCPInfo deltas. Dart WebSocket writes never block, so client-side byte
    // counting measures buffer fill, not the network — whether it may be
    // used as a fallback is a per-platform strategy decision.
    final tracker = _strategy.createUploadTracker(_settings);

    final completer = Completer<Ndt7Measurement>();
    var sendLoopActive = true;

    // Listen for server messages BEFORE the send loop so that onDone
    // fires reliably when the timer closes the WebSocket below.
    ws.listen(
      (message) {
        if (message is String) {
          final measurement = _parseNdt7Message(message);
          if (measurement != null) {
            if (measurement.minRTT != null) {
              minRTT = minRTT == null
                  ? measurement.minRTT
                  : (measurement.minRTT! < minRTT!
                      ? measurement.minRTT
                      : minRTT);
            }
            if (measurement.retransmissions != null) {
              retransmissions = retransmissions == null
                  ? measurement.retransmissions
                  : (measurement.retransmissions! > retransmissions!
                      ? measurement.retransmissions
                      : retransmissions);
            }
            if (measurement.retransmissionPercentage != null) {
              retransmissionPercentage = measurement.retransmissionPercentage;
            }
            tracker.onServerMeasurement(
              measurement,
              DateTime.now().difference(startTime),
            );
          }
        }
      },
      onError: (error) {
        sendLoopActive = false;
        _activeTimer?.cancel();
        _activeTimer = null;
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception('Upload test failed: $error', null, error),
          );
        }
      },
      onDone: () {
        _activeTimer?.cancel();
        _activeTimer = null;
        final finalThroughput = tracker.throughputMbps ?? 0.0;
        print(
            'Ndt7Service upload test complete. trackerThroughput: ${tracker.throughputMbps}, final: $finalThroughput');
        if (!completer.isCompleted) {
          completer.complete(Ndt7Measurement(
            throughputMbps: finalThroughput,
            minRTT: minRTT,
            retransmissions: retransmissions,
            retransmissionPercentage: retransmissionPercentage,
          ));
        }
      },
    );

    const chunkSize = 8192;
    var lastProgressTime = startTime;

    // addStream applies kernel-socket backpressure: the producer resumes the
    // instant the socket drains, so throughput matches the link rate while
    // memory stays bounded (a busy-wait here throttles to one chunk per wait).
    Completer<void>? pauseGate;
    final controller = StreamController<Uint8List>(
      onPause: () => pauseGate ??= Completer<void>(),
      onResume: () {
        pauseGate?.complete();
        pauseGate = null;
      },
    );

    _activeTimer = Timer(_settings.uploadTestDuration, () {
      _activeTimer = null;
      sendLoopActive = false;
      // Release the producer if it is waiting on a pause gate, then close
      // the WebSocket to trigger onDone above. The NDT7 server may not
      // close its side on its own, so the client must initiate.
      pauseGate?.complete();
      pauseGate = null;
      ws.close();
    });

    () async {
      while (sendLoopActive) {
        final gate = pauseGate;
        if (gate != null) {
          await gate.future;
          continue;
        }
        final data = Uint8List(chunkSize);
        for (var i = 0; i < chunkSize; i++) {
          data[i] = i & 0xFF;
        }
        controller.add(data);
        totalBytes += chunkSize;

        final now = DateTime.now();
        final testElapsed = now.difference(startTime);
        tracker.onClientBytes(totalBytes, testElapsed);
        final progressElapsed = now.difference(lastProgressTime);
        if (progressElapsed >= const Duration(milliseconds: 250)) {
          onProgress?.call(Ndt7Progress(
            elapsed: testElapsed.inMilliseconds / 1000.0,
            speed: tracker.throughputMbps ?? 0.0,
            bytesTransferred: totalBytes,
            isDownload: false,
          ));
          lastProgressTime = now;
        }

        await Future<void>.delayed(Duration.zero);
      }
      await controller.close();
    }();

    try {
      await ws.addStream(controller.stream);
    } catch (_) {
      // Expected when the connection closes
    }

    return await completer.future;
  }

  Ndt7Measurement? _parseNdt7Message(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      double? throughputMbps;
      double? minRTT;
      int? retransmissions;
      int? bytesSent;
      int? bytesRetrans;
      int? bytesReceived;
      int? elapsedTimeUs;
      double? retransmissionPercentage;

      final tcpInfo = data['TCPInfo'] as Map<String, dynamic>?;
      if (tcpInfo != null) {
        bytesSent = tcpInfo['BytesSent'] as int?;
        bytesRetrans = tcpInfo['BytesRetrans'] as int?;
        bytesReceived = tcpInfo['BytesReceived'] as int?;
        elapsedTimeUs = tcpInfo['ElapsedTime'] as int?;
        minRTT = tcpInfo['MinRTT'] != null
            ? (tcpInfo['MinRTT'] as num).toDouble() / 1000.0
            : null;
        retransmissions = tcpInfo['Retransmissions'] as int?;

        // Only meaningful on connections that carried actual data (the
        // upload connection sends ~56 KB of control bytes from the server,
        // which would yield a bogus retransmission ratio).
        if (bytesSent != null && bytesRetrans != null && bytesSent > 1000000) {
          retransmissionPercentage = (bytesRetrans / bytesSent) * 100.0;
        }
      }

      // AppInfo carries NumBytes (bytes) and ElapsedTime (microseconds) during
      // the download phase. Calculate throughput: (bytes * 8) / (us / 1e6) / 1e6 = Mbps
      final appInfo = data['AppInfo'] as Map<String, dynamic>?;
      if (appInfo != null) {
        final numBytes = appInfo['NumBytes'] as int?;
        final elapsedUs = appInfo['ElapsedTime'] as int?;
        if (numBytes != null && elapsedUs != null && elapsedUs > 0) {
          final elapsedSec = elapsedUs / 1e6;
          throughputMbps = (numBytes * 8) / elapsedSec / 1000000;
        }
      }

      if (throughputMbps == null &&
          minRTT == null &&
          retransmissions == null &&
          bytesReceived == null) {
        return null;
      }

      return Ndt7Measurement(
        throughputMbps: throughputMbps,
        minRTT: minRTT,
        retransmissions: retransmissions,
        bytesSent: bytesSent,
        bytesRetrans: bytesRetrans,
        bytesReceived: bytesReceived,
        elapsedTimeUs: elapsedTimeUs,
        retransmissionPercentage: retransmissionPercentage,
      );
    } catch (e) {
      debugPrint('Ndt7Service: failed to parse message: $e');
      return null;
    }
  }

  double _calculateThroughput(int bytes, Duration elapsed) {
    if (elapsed.inMilliseconds == 0) return 0;
    final bits = bytes * 8;
    final seconds = elapsed.inMilliseconds / 1000.0;
    final bps = bits / seconds;
    return bps / 1000000;
  }

  void dispose() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeWebSocket?.close();
    _activeWebSocket = null;
    _httpClient.close();
  }
}

typedef WebSocketFactory = Future<WebSocket> Function(
  String url, {
  List<String>? protocols,
});

Future<WebSocket> _defaultWebSocketFactory(
  String url, {
  List<String>? protocols,
}) {
  return WebSocket.connect(url, protocols: protocols);
}

class Ndt7Exception implements Exception {
  const Ndt7Exception(this.message, [this.statusCode, this.cause]);

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'Ndt7Exception: $message';
}
