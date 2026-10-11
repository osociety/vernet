enum ServerCheckType { icmp, tcp, http, https }

class ServerMonitor {
  const ServerMonitor({
    required this.id,
    required this.name,
    required this.host,
    required this.type,
    this.port,
    this.expectedText = '',
    this.intervalSeconds = 60,
  });

  factory ServerMonitor.fromJson(Map<String, dynamic> json) => ServerMonitor(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        type: ServerCheckType.values.byName(json['type'] as String),
        port: json['port'] as int?,
        expectedText: json['expectedText'] as String? ?? '',
        intervalSeconds: json['intervalSeconds'] as int? ?? 60,
      );

  final String id;
  final String name;
  final String host;
  final ServerCheckType type;
  final int? port;
  final String expectedText;
  final int intervalSeconds;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'type': type.name,
        'port': port,
        'expectedText': expectedText,
        'intervalSeconds': intervalSeconds,
      };
}

class ServerCheckResult {
  const ServerCheckResult({
    required this.checkedAt,
    required this.isUp,
    required this.latency,
    this.message = '',
  });

  factory ServerCheckResult.fromJson(Map<String, dynamic> json) =>
      ServerCheckResult(
        checkedAt: DateTime.parse(json['checkedAt'] as String),
        isUp: json['isUp'] as bool,
        latency: (json['latencyMs'] as int?) == null
            ? null
            : Duration(milliseconds: json['latencyMs'] as int),
        message: json['message'] as String? ?? '',
      );

  final DateTime checkedAt;
  final bool isUp;
  final Duration? latency;
  final String message;

  Map<String, Object?> toJson() => {
        'checkedAt': checkedAt.toIso8601String(),
        'isUp': isUp,
        'latencyMs': latency?.inMilliseconds,
        'message': message,
      };
}
