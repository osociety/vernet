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
      retransmissions: downloadResult.retransmissions ??
          uploadResult.retransmissions,
      timestamp: DateTime.now(),
    );
  }

  /// Runs download test only.
  Future<Ndt7Measurement> runDownloadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
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
    final throughputSamples = <double>[];

    final completer = Completer<Ndt7Measurement>();
    _activeTimer = Timer(_downloadTestDuration, () {
      _activeTimer = null;
      if (!completer.isCompleted) {
        completer.complete(_buildMeasurement(
          throughputSamples,
          minRTT,
          retransmissions,
        ));
      }
    });

    ws.listen(
      (message) {
        if (message is List<int>) {
          totalBytes += message.length;
          final elapsed = DateTime.now().difference(startTime);
          final throughputMbps = _calculateThroughput(totalBytes, elapsed);

          onProgress?.call(Ndt7Progress(
            elapsed: elapsed.inMilliseconds / 1000.0,
            speed: throughputMbps,
            bytesTransferred: totalBytes,
            isDownload: true,
          ));

          throughputSamples.add(throughputMbps);
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
          final throughputMbps = _calculateThroughput(totalBytes, elapsed);
          completer.complete(Ndt7Measurement(
            throughputMbps: throughputMbps,
            minRTT: minRTT,
            retransmissions: retransmissions,
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
    final throughputSamples = <double>[];

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
          completer.complete(_buildMeasurement(
            throughputSamples,
            minRTT,
            retransmissions,
          ));
        }
      },
    );

    _activeTimer = Timer(_uploadTestDuration, () {
      _activeTimer = null;
      sendLoopActive = false;
      // Close the WebSocket to trigger onDone above. The NDT7 server
      // may not close its side on its own, so the client must initiate.
      ws.close();
    });

    const chunkSize = 8192;
    var sampleIndex = 0;
    var batchCount = 0;
    while (sendLoopActive && ws.readyState == WebSocket.open) {
      final data = Uint8List(chunkSize);
      for (var i = 0; i < chunkSize; i++) {
        data[i] = i & 0xFF;
      }
      ws.add(data);
      totalBytes += chunkSize;
      batchCount++;

      // Yield to the event loop every 16 sends (~128 KB) to let the
      // WebSocket flush and TCP backpressure propagate.
      if (batchCount >= 16) {
        batchCount = 0;
        await Future<void>.delayed(Duration.zero);
      }

      final elapsed = DateTime.now().difference(startTime);
      final throughputMbps = _calculateThroughput(totalBytes, elapsed);

      // Skip the first 3 samples to avoid initial spike noise.
      if (sampleIndex >= 3) {
        onProgress?.call(Ndt7Progress(
          elapsed: elapsed.inMilliseconds / 1000.0,
          speed: throughputMbps,
          bytesTransferred: totalBytes,
          isDownload: false,
        ));
        throughputSamples.add(throughputMbps);
      }
      sampleIndex++;
    }

    return await completer.future;
  }

  Ndt7Measurement _buildMeasurement(
    List<double> throughputSamples,
    double? minRTT,
    int? retransmissions,
  ) {
    final avgThroughput = throughputSamples.isEmpty
        ? 0.0
        : throughputSamples.reduce((a, b) => a + b) / throughputSamples.length;
    return Ndt7Measurement(
      throughputMbps: avgThroughput,
      minRTT: minRTT,
      retransmissions: retransmissions,
    );
  }

  Ndt7Measurement? _parseNdt7Message(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      // Try TCPInfo first (contains MinRTT, RTT, retransmissions)
      final tcpInfo = data['TCPInfo'] as Map<String, dynamic>?;
      if (tcpInfo != null) {
        return Ndt7Measurement(
          minRTT: tcpInfo['MinRTT'] != null
              ? (tcpInfo['MinRTT'] as num).toDouble() / 1000.0
              : null,
          retransmissions: tcpInfo['Retransmissions'] as int?,
        );
      }

      // Fall back to AppInfo (contains throughput)
      final appInfo = data['AppInfo'] as Map<String, dynamic>?;
      if (appInfo == null) return null;

      return Ndt7Measurement(
        throughputMbps: appInfo['ThroughputValue'] != null
            ? (appInfo['ThroughputValue'] as num).toDouble()
            : null,
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

class Ndt7Measurement {
  const Ndt7Measurement({
    this.throughputMbps,
    this.minRTT,
    this.retransmissions,
  });

  final double? throughputMbps;
  final double? minRTT;
  final int? retransmissions;
}

class Ndt7Exception implements Exception {
  const Ndt7Exception(this.message, [this.statusCode, this.cause]);

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'Ndt7Exception: $message';
}
