class WifiInfo {
  WifiInfo(
    this._ip,
    this._bssid,
    this._name,
    this.unknown,
    this.gatewayIp,
    this.isLocationOn,
  );

  static Set<String> defaultBSSID = {'00:00:00:00:00:00'};
  final String? _bssid;
  final String? _ip;
  final String? _name;
  bool unknown;
  String get ip => _ip ?? 'x.x.x.x';
  int totalDevices = 0;
  final String gatewayIp;
  final bool isLocationOn;
  String get subnet => gatewayIp.substring(0, gatewayIp.lastIndexOf('.'));

  static const String noWifiName = 'Wi-Fi';

  String get name {
    if (_name == null || _name.isEmpty) return noWifiName;
    if (_name.startsWith('"') && _name.endsWith('"')) {
      final array = _name.split('"');
      if (array.length > 1) {
        final wifiName = array[1];
        return wifiName.isEmpty ? noWifiName : wifiName;
      }
    }
    return _name;
  }

  String get bssid => _bssid ?? defaultBSSID.first;
}
