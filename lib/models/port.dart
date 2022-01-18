class Port {
  String _desc;
  bool _udp;
  bool _tcp;
  String _port;
  String _status;

  String get desc => _desc;
  bool get isUDP => _udp;
  bool get isTCP => _tcp;
  String get port => _port;
  String get status => _status;

  Port.fromJson(dynamic map)
      : _desc = map['description'] as String,
        _tcp = map['tcp'] as bool,
        _udp = map['udp'] as bool,
        _port = map['port'] as String,
        _status = map['status'] as String;
}
