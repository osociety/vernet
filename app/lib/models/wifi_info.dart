class WifiInfo {
  String? _bssid;
  String? _ip;
  String? _name;
  bool unknown;
  String get ip => _ip ?? 'x.x.x.x';
  String get name => _name ?? 'Unknown Wifi';
  String get bssid => _bssid ?? 'Unknown ID';

  WifiInfo(this._ip, this._bssid, this._name, this.unknown);
}
