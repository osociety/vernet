import 'package:vernet/models/wifi_metrics.dart';

class WifiInfo {
  WifiInfo(this._ip, this._bssid, this._name, this.unknown, this.gatewayIp,
      this.isLocationOn, this.metrics,
      {String? scanSubnet, this.dhcpServerIp})
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

  /// The host that leased this device's address, where the platform reports it.
  ///
  /// Only Android exposes the lease, and it is the gateway only by coincidence,
  /// so this never stands in for [gatewayIp]. Null means "not reported".
  final String? dhcpServerIp;

  /// The seed address the host scan targets, if the user chose another network.
  ///
  /// Null means the scan runs on the detected gateway's subnet.
  final String? _scanSubnet;

  /// Address the host scan runs against: the saved custom seed when there is
  /// one, otherwise [gatewayIp].
  String get scanSubnet {
    final custom = _scanSubnet ?? '';
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
    final raw = _name;
    // The platform wraps the SSID in one pair of quotes, so only those two are
    // removed. Splitting on every quote cut a network whose own name contains
    // one, and a phone on `Cafe "Free" WiFi` showed `Cafe `.
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      final wifiName = raw.substring(1, raw.length - 1);
      return wifiName.isEmpty ? noWifiName : wifiName;
    }
    return raw;
  }

  String get bssid => _bssid ?? defaultBSSID.first;
}
