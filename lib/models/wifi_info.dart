class WifiInfo {
  static Set<String> defaultBSSID = {'00:00:00:00:00:00'};
  String? _bssid;
  String? _ip;
  String? _name;
  bool unknown;
  String get ip => _ip ?? 'x.x.x.x';
  String get name => _name ?? 'Wi-Fi';
  String get bssid => _bssid ?? defaultBSSID.first;

  WifiInfo(this._ip, this._bssid, this._name, this.unknown);
}
