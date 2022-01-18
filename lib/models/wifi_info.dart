class WifiInfo {
  WifiInfo(this._ip, this._bssid, this._name, this.unknown);

  static Set<String> defaultBSSID = {'00:00:00:00:00:00'};
  final String? _bssid;
  final String? _ip;
  final String? _name;
  bool unknown;
  String get ip => _ip ?? 'x.x.x.x';
  String get name => _name ?? 'Wi-Fi';
  String get bssid => _bssid ?? defaultBSSID.first;
}
