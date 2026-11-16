import 'package:vernet/models/wifi_metrics.dart';

class WifiInfo {
  WifiInfo(this._ip, this._bssid, this._name, this.unknown, this.gatewayIp,
      this.isLocationOn, this.metrics,
      {String? scanSubnet})
      : _scanSubnet = scanSubnet;

  static Set<String> defaultBSSID = {'00:00:00:00:00:00'};
  final String? _bssid;
  final String? _ip;
  final String? _name;
  final WifiNetworkMetrics metrics;
  bool unknown;
  String get ip => _ip ?? 'x.x.x.x';
  int totalDevices = 0;

  /// Gateway of the network this device is on, as the platform reports it.
  ///
  /// "Search a different network" saves a seed address for the host scan. That
  /// seed is not this device's router, so it never replaces this value.
  final String gatewayIp;
  final bool isLocationOn;

  /// The seed address the host scan targets, if the user chose another network.
  ///
  /// Null means the scan runs on the detected gateway's subnet.
  final String? _scanSubnet;

  /// Address the host scan runs against: the saved custom seed when there is
  /// one, otherwise [gatewayIp].
  String get scanSubnet {
    final custom = _scanSubnet?.trim() ?? '';
    return custom.isEmpty ? gatewayIp : custom;
  }

  /// The first three octets of [scanSubnet], which is the range the scan sweeps.
  String get subnet => _prefixOf(scanSubnet);

  static String _prefixOf(String address) => address.contains('.')
      ? address.substring(0, address.lastIndexOf('.'))
      : address;

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
