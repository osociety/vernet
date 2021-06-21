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
      : _desc = map['description'],
        _tcp = map['tcp'],
        _udp = map['udp'],
        _port = map['port'],
        _status = map['status'];
}
