class WakeOnLanTarget {
  const WakeOnLanTarget({
    required this.label,
    required this.macAddress,
    this.ipv4Address = '255.255.255.255',
    this.port = 9,
    this.password = '',
  });

  factory WakeOnLanTarget.fromJson(Map<String, dynamic> json) {
    return WakeOnLanTarget(
      label: json['label'] as String? ?? '',
      macAddress: json['macAddress'] as String? ?? '',
      ipv4Address: json['ipv4Address'] as String? ?? '255.255.255.255',
      port: json['port'] as int? ?? 9,
      password: json['password'] as String? ?? '',
    );
  }

  final String label;
  final String macAddress;
  final String ipv4Address;
  final int port;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'macAddress': macAddress,
      'ipv4Address': ipv4Address,
      'port': port,
      'password': password,
    };
  }

  WakeOnLanTarget copyWith({
    String? label,
    String? macAddress,
    String? ipv4Address,
    int? port,
    String? password,
  }) {
    return WakeOnLanTarget(
      label: label ?? this.label,
      macAddress: macAddress ?? this.macAddress,
      ipv4Address: ipv4Address ?? this.ipv4Address,
      port: port ?? this.port,
      password: password ?? this.password,
    );
  }
}

class WakeOnLanResult {
  const WakeOnLanResult({
    required this.macAddress,
    required this.ipv4Address,
    required this.port,
    required this.repeat,
  });

  final String macAddress;
  final String ipv4Address;
  final int port;
  final int repeat;
}
