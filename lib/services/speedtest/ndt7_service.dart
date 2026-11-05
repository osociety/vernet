import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:vernet/models/ndt7_result.dart';

/// Service for M-Lab NDT7 speed test protocol.
///
/// Uses the Locate v2 API for server discovery and implements the NDT7
/// WebSocket protocol for accurate throughput, latency, and packet loss
/// measurements.
@injectable
class Ndt7Service {
  Ndt7Service()
      : _httpClient = http.Client(),
        _webSocketFactory = _defaultWebSocketFactory;

  Ndt7Service.withDependencies({
    required http.Client httpClient,
    required WebSocketFactory webSocketFactory,
  })  : _httpClient = httpClient,
        _webSocketFactory = webSocketFactory;

  final http.Client _httpClient;
  final WebSocketFactory _webSocketFactory;

  static const _locateApiUrl =
      'https://locate.measurementlab.net/v2/nearest/ndt/ndt7';
  static const _ndt7Subprotocol = 'net.measurementlab.ndt.v7';
  static const _downloadTestDuration = Duration(seconds: 10);
  static const _uploadTestDuration = Duration(seconds: 10);
  static const _connectionTimeout = Duration(seconds: 15);

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

      return results
          .map((r) => Ndt7Server.fromJson(r as Map<String, dynamic>))
          .where((s) => s.urls.downloadUrl != null && s.urls.uploadUrl != null)
          .toList();
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
      timer = Timer(_connectionTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception(
              'WebSocket connection timed out after ${_connectionTimeout.inSeconds}s',
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
    double? latestServerThroughput;
    final throughputSamples = <double>[];
    // Warm-up period: discard first 2 seconds of samples to avoid TCP ramp-up skew
    const warmupDuration = Duration(seconds: 2);

    final completer = Completer<Ndt7Measurement>();
    _activeTimer = Timer(_downloadTestDuration, () {
      _activeTimer = null;
      if (!completer.isCompleted) {
        completer.complete(Ndt7Measurement(
          // Use last server throughput sample (official NDT7 methodology),
          // falling back to client-side median if server samples unavailable
          throughputMbps: latestServerThroughput ??
              _calculateMedianThroughput(throughputSamples) ??
              0.0,
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

          // Skip warm-up period for sample collection
          if (elapsed > warmupDuration) {
            final throughputMbps = _calculateThroughput(totalBytes, elapsed);
            throughputSamples.add(throughputMbps);

            // Use server measurement for progress if available, otherwise client-side
            final progressSpeed = latestServerThroughput ?? throughputMbps;

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
            if (measurement.throughputMbps != null) {
              final elapsed = DateTime.now().difference(startTime);
              // Only collect server samples after warm-up
              if (elapsed > warmupDuration) {
                latestServerThroughput = measurement.throughputMbps;
              }
            }
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
          completer.complete(Ndt7Measurement(
            throughputMbps:
                latestServerThroughput ?? clientThroughputMbps,
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
    // Official NDT7 methodology (ndt7-client-go): upload throughput is
    // measured at the receiver (the server) from the latest TCPInfo sample
    // as 8 * BytesReceived / ElapsedTime. Dart WebSocket writes never block,
    // so client-side byte counting measures buffer fill, not the network.
    double? latestUploadMbps;

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
            // Use AppInfo throughput (application-level goodput) if available,
            // falling back to TCPInfo calculation only if AppInfo not provided
            if (measurement.throughputMbps != null) {
              latestUploadMbps = measurement.throughputMbps;
              print('Ndt7Service upload: $latestUploadMbps Mbps '
                  '(from AppInfo NumBytes=${measurement.bytesSent} bytes)');
            } else {
              final elapsedUs = measurement.elapsedTimeUs ?? 0;
              final bytesReceived = measurement.bytesReceived;
              if (bytesReceived != null && elapsedUs > 0) {
                final elapsedSec = elapsedUs / 1e6;
                latestUploadMbps = 8 * bytesReceived / elapsedSec / 1000000;
                print('Ndt7Service upload: $latestUploadMbps Mbps '
                    '(from TCPInfo: $bytesReceived bytes in ${elapsedUs}us)');
              }
            }
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
        if (!completer.isCompleted) {
          completer.complete(Ndt7Measurement(
            throughputMbps: latestUploadMbps ?? 0.0,
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

    _activeTimer = Timer(_uploadTestDuration, () {
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
        final progressElapsed = now.difference(lastProgressTime);
        if (progressElapsed >= const Duration(milliseconds: 250)) {
          onProgress?.call(Ndt7Progress(
            elapsed: now.difference(startTime).inMilliseconds / 1000.0,
            speed: latestUploadMbps ?? 0.0,
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
      print('Ndt7Service parsing message: ${data.keys.toList()}');

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
        print('Ndt7Service TCPInfo: BytesSent=$bytesSent, BytesReceived=$bytesReceived, ElapsedTime=$elapsedTimeUs');
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
        print('Ndt7Service AppInfo: NumBytes=$numBytes, ElapsedTime=$elapsedUs');
        if (numBytes != null && elapsedUs != null && elapsedUs > 0) {
          final elapsedSec = elapsedUs / 1e6;
          throughputMbps = (numBytes * 8) / elapsedSec / 1000000;
          print('Ndt7Service calculated throughput: $throughputMbps Mbps');
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

  /// Calculates median throughput from samples, which is more robust than
  /// average for handling outliers and TCP ramp-up variance.
  double? _calculateMedianThroughput(List<double> samples) {
    if (samples.isEmpty) return null;
    final sorted = List<double>.from(samples)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
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

class Ndt7Measurement {
  const Ndt7Measurement({
    this.throughputMbps,
    this.minRTT,
    this.retransmissions,
    this.bytesSent,
    this.bytesRetrans,
    this.bytesReceived,
    this.elapsedTimeUs,
    this.retransmissionPercentage,
  });

  final double? throughputMbps;
  final double? minRTT;
  final int? retransmissions;
  final int? bytesSent;
  final int? bytesRetrans;
  final int? bytesReceived;
  final int? elapsedTimeUs;
  final double? retransmissionPercentage;
}

class Ndt7Exception implements Exception {
  const Ndt7Exception(this.message, [this.statusCode, this.cause]);

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'Ndt7Exception: $message';
}
