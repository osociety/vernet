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
          ? Ndt7ServerLocation.fromJson(json['location'] as Map<String, dynamic>)
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
    return Ndt7ServerUrls(
      downloadUrl: json['wss:///ndt/v7/download'] as String? ??
          json['ws:///ndt/v7/download'] as String?,
      uploadUrl: json['wss:///ndt/v7/upload'] as String? ??
          json['ws:///ndt/v7/upload'] as String?,
    );
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

/// Final result from an NDT7 speed test.
class Ndt7TestResult {
  const Ndt7TestResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    required this.server,
    this.minRTT,
    this.retransmissions,
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
  final DateTime? timestamp;

  /// Packet loss percentage (estimated from retransmissions if available).
  double? get packetLossPercent {
    if (retransmissions == null) return null;
    // Rough estimate: retransmissions as percentage of total packets
    // NDT7 doesn't directly report packet loss, so we estimate from retransmissions
    return (retransmissions! / 1000).clamp(0.0, 100.0);
  }

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
        'timestamp': timestamp?.toIso8601String(),
      };
}
