// Models for M-Lab NDT7 speed test protocol.
//
// NDT7 uses WebSocket connections to M-Lab servers for accurate
// throughput, latency, and packet loss measurements.
// See: https://www.measurementlab.net/develop/

class Ndt7Server {
  const Ndt7Server({
    required this.machine,
    required this.site,
    required this.urls,
    this.location,
    this.ttl,
  });

  factory Ndt7Server.fromJson(Map<String, dynamic> json) {
    final urlsJson = json['urls'] as Map<String, dynamic>? ?? {};
    return Ndt7Server(
      machine: json['machine'] as String? ?? '',
      site: json['site'] as String? ?? '',
      urls: Ndt7ServerUrls.fromJson(urlsJson),
      location: json['location'] != null
          ? Ndt7ServerLocation.fromJson(
              json['location'] as Map<String, dynamic>)
          : null,
      ttl: json['ttl'] as int?,
    );
  }

  final String machine;
  final String site;
  final Ndt7ServerUrls urls;
  final Ndt7ServerLocation? location;
  final int? ttl;

  String get displayName => location?.city ?? site;
  String get displayCountry => location?.country ?? '';
}

class Ndt7ServerUrls {
  const Ndt7ServerUrls({
    this.downloadUrl,
    this.uploadUrl,
  });

  factory Ndt7ServerUrls.fromJson(Map<String, dynamic> json) {
    final rawDownload = json['wss:///ndt/v7/download'] as String? ??
        json['ws:///ndt/v7/download'] as String?;
    final rawUpload = json['wss:///ndt/v7/upload'] as String? ??
        json['ws:///ndt/v7/upload'] as String?;

    final downloadUrl = _sanitizeUrl(rawDownload);
    final uploadUrl = _sanitizeUrl(rawUpload);

    return Ndt7ServerUrls(
      downloadUrl: downloadUrl,
      uploadUrl: uploadUrl,
    );
  }

  /// Strips the bogus `:0` port the Locate API sometimes returns.
  ///
  /// M-Lab's Locate v2 API occasionally includes `:0` in server URLs
  /// (e.g. `wss://host:0/ndt/v7/download`). WebSocket.connect rejects
  /// port 0, so we rebuild the URL without it.
  static String? _sanitizeUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.port != 0) return url;
    // Rebuild without the port so the scheme default is used.
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      path: uri.path,
      query: uri.query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    ).toString();
  }

  final String? downloadUrl;
  final String? uploadUrl;
}

class Ndt7ServerLocation {
  const Ndt7ServerLocation({
    this.city,
    this.country,
  });

  factory Ndt7ServerLocation.fromJson(Map<String, dynamic> json) {
    return Ndt7ServerLocation(
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }

  final String? city;
  final String? country;
}

/// Real-time progress update during NDT7 test.
class Ndt7Progress {
  const Ndt7Progress({
    required this.elapsed,
    required this.speed,
    required this.bytesTransferred,
    required this.isDownload,
  });

  final double elapsed;
  final double speed;
  final int bytesTransferred;
  final bool isDownload;
}

/// Measurement observed on the NDT7 WebSocket: a parsed server TCPInfo /
/// AppInfo message with cumulative counters, or the final client-side result
/// of one test direction.
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

/// Final result from an NDT7 speed test.
class Ndt7TestResult {
  const Ndt7TestResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    required this.server,
    this.minRTT,
    this.retransmissions,
    this.retransmissionPercentage,
    this.timestamp,
  });

  factory Ndt7TestResult.fromJson(Map<String, dynamic> json) {
    final serverJson = json['server'] as Map<String, dynamic>;
    return Ndt7TestResult(
      downloadMbps: (json['downloadMbps'] as num).toDouble(),
      uploadMbps: (json['uploadMbps'] as num).toDouble(),
      latencyMs: (json['latencyMs'] as num).toDouble(),
      server: Ndt7Server(
        machine: serverJson['machine'] as String? ?? '',
        site: serverJson['site'] as String? ?? '',
        urls: const Ndt7ServerUrls(),
        location: serverJson['location'] != null
            ? Ndt7ServerLocation.fromJson(
                serverJson['location'] as Map<String, dynamic>)
            : null,
      ),
      minRTT: (json['minRTT'] as num?)?.toDouble(),
      retransmissions: json['retransmissions'] as int?,
      retransmissionPercentage:
          (json['retransmissionPercentage'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  final double downloadMbps;
  final double uploadMbps;
  final double latencyMs;
  final Ndt7Server server;
  final double? minRTT;
  final int? retransmissions;
  final double? retransmissionPercentage;
  final DateTime? timestamp;

  Map<String, dynamic> toJson() => {
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'latencyMs': latencyMs,
        'server': {
          'machine': server.machine,
          'site': server.site,
          'location': server.location != null
              ? {
                  'city': server.location!.city,
                  'country': server.location!.country,
                }
              : null,
        },
        'minRTT': minRTT,
        'retransmissions': retransmissions,
        'retransmissionPercentage': retransmissionPercentage,
        'timestamp': timestamp?.toIso8601String(),
      };
}
