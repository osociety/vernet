import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
    final downloadResult = await _runDownloadTest(
      server,
      onProgress: onProgress,
    );
    final uploadResult = await _runUploadTest(
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

  Future<_Ndt7Measurement> _runDownloadTest(
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

  Future<_Ndt7Measurement> _runUploadTest(
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

  Future<WebSocket> _connectWebSocket(String url) {
    try {
      return _webSocketFactory(
        url,
        protocols: [_ndt7Subprotocol],
      );
    } on WebSocketException catch (e) {
      throw Ndt7Exception('WebSocket connection failed: ${e.message}', null, e);
    }
  }

  Future<_Ndt7Measurement> _measureDownload(
    WebSocket ws, {
    void Function(Ndt7Progress)? onProgress,
  }) {
    final startTime = DateTime.now();
    var totalBytes = 0;
    double? minRTT;
    int? retransmissions;
    final throughputSamples = <double>[];

    final completer = Completer<_Ndt7Measurement>();
    Timer? timeoutTimer;

    timeoutTimer = Timer(_downloadTestDuration, () {
      if (!completer.isCompleted) {
        final avgThroughput = throughputSamples.isEmpty
            ? 0.0
            : throughputSamples.reduce((a, b) => a + b) /
                throughputSamples.length;
        completer.complete(_Ndt7Measurement(
          throughputMbps: avgThroughput,
          minRTT: minRTT,
          retransmissions: retransmissions,
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
            minRTT ??= measurement.minRTT;
            retransmissions ??= measurement.retransmissions;
          }
        }
      },
      onError: (error) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception('Download test failed: $error', null, error),
          );
        }
      },
      onDone: () {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          final elapsed = DateTime.now().difference(startTime);
          final throughputMbps = _calculateThroughput(totalBytes, elapsed);
          completer.complete(_Ndt7Measurement(
            throughputMbps: throughputMbps,
            minRTT: minRTT,
            retransmissions: retransmissions,
          ));
        }
      },
    );

    return completer.future;
  }

  Future<_Ndt7Measurement> _measureUpload(
    WebSocket ws, {
    void Function(Ndt7Progress)? onProgress,
  }) {
    final startTime = DateTime.now();
    var totalBytes = 0;
    double? minRTT;
    int? retransmissions;
    final throughputSamples = <double>[];

    final completer = Completer<_Ndt7Measurement>();
    Timer? timeoutTimer;
    Timer? sendTimer;

    timeoutTimer = Timer(_uploadTestDuration, () {
      sendTimer?.cancel();
      if (!completer.isCompleted) {
        final avgThroughput = throughputSamples.isEmpty
            ? 0.0
            : throughputSamples.reduce((a, b) => a + b) /
                throughputSamples.length;
        completer.complete(_Ndt7Measurement(
          throughputMbps: avgThroughput,
          minRTT: minRTT,
          retransmissions: retransmissions,
        ));
      }
    });

    // Send data in chunks
    const chunkSize = 8192;
    final rng = Random();
    sendTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (ws.readyState != WebSocket.open) {
        sendTimer?.cancel();
        return;
      }

      final data = Uint8List(chunkSize);
      for (var i = 0; i < chunkSize; i++) {
        data[i] = rng.nextInt(256);
      }
      ws.add(data);
      totalBytes += chunkSize;

      final elapsed = DateTime.now().difference(startTime);
      final throughputMbps = _calculateThroughput(totalBytes, elapsed);

      onProgress?.call(Ndt7Progress(
        elapsed: elapsed.inMilliseconds / 1000.0,
        speed: throughputMbps,
        bytesTransferred: totalBytes,
        isDownload: false,
      ));

      throughputSamples.add(throughputMbps);
    });

    // Listen for server measurements
    ws.listen(
      (message) {
        if (message is String) {
          final measurement = _parseNdt7Message(message);
          if (measurement != null) {
            minRTT ??= measurement.minRTT;
            retransmissions ??= measurement.retransmissions;
          }
        }
      },
      onError: (error) {
        sendTimer?.cancel();
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            Ndt7Exception('Upload test failed: $error', null, error),
          );
        }
      },
    );

    return completer.future;
  }

  _Ndt7Measurement? _parseNdt7Message(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final appInfo = data['AppInfo'] as Map<String, dynamic>?;
      if (appInfo == null) return null;

      return _Ndt7Measurement(
        throughputMbps: appInfo['ThroughputValue'] != null
            ? (appInfo['ThroughputValue'] as num).toDouble()
            : null,
        minRTT: appInfo['MinRTT'] != null
            ? (appInfo['MinRTT'] as num).toDouble()
            : null,
        retransmissions: appInfo['Retransmissions'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  double _calculateThroughput(int bytes, Duration elapsed) {
    if (elapsed.inMilliseconds == 0) return 0;
    final bits = bytes * 8;
    final seconds = elapsed.inMilliseconds / 1000.0;
    final bps = bits / seconds;
    return bps / 1000000; // Convert to Mbps
  }

  void dispose() {
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

class _Ndt7Measurement {
  const _Ndt7Measurement({
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
