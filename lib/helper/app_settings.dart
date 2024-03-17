import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();

  static const String _lastSubnetKey = 'AppSettings-LAST_SUBNET';
  static const String _firstSubnetKey = 'AppSettings-FIRST_SUBNET';
  static const String _socketTimeoutKey = 'AppSettings-SOCKET_TIMEOUT';
  static const String _pingCountKey = 'AppSettings-PING_COUNT';
  static const String _inAppInternetKey = 'AppSettings-IN-APP-INTERNET';
  static const String _customSubnetKey = 'AppSettings-CUSTOM-SUBNET';
  int _firstSubnet = 1;
  int _lastSubnet = 254;
  int _socketTimeout = 500;
  int _pingCount = 5;
  bool _inAppInternet = false;
  String _customSubnet = '';

  static final AppSettings _instance = AppSettings._();

  static AppSettings get instance => _instance;
  int get firstSubnet => _firstSubnet;
  int get lastSubnet => _lastSubnet;
  int get socketTimeout => _socketTimeout;
  int get pingCount => _pingCount;
  bool get inAppInternet => _inAppInternet;
  String get customSubnet => _customSubnet;
  String get gatewayIP => _customSubnet.isNotEmpty
      ? _customSubnet.substring(0, _customSubnet.lastIndexOf('.'))
      : _customSubnet;

  Future<bool> setFirstSubnet(int firstSubnet) async {
    _firstSubnet = firstSubnet;
    return (await SharedPreferences.getInstance())
        .setInt(_firstSubnetKey, _firstSubnet);
  }

  Future<bool> setLastSubnet(int lastSubnet) async {
    _lastSubnet = lastSubnet;
    return (await SharedPreferences.getInstance())
        .setInt(_lastSubnetKey, _lastSubnet);
  }

  Future<bool> setSocketTimeout(int socketTimeout) async {
    _socketTimeout = socketTimeout;
    return (await SharedPreferences.getInstance())
        .setInt(_socketTimeoutKey, _socketTimeout);
  }

  Future<bool> setPingCount(int pingCount) async {
    _pingCount = pingCount;
    return (await SharedPreferences.getInstance())
        .setInt(_pingCountKey, _pingCount);
  }

  Future<bool> setInAppInternet(bool inAppInternet) async {
    _inAppInternet = inAppInternet;
    return (await SharedPreferences.getInstance())
        .setBool(_inAppInternetKey, _inAppInternet);
  }

  Future<bool> setCustomSubnet(String customSubnet) async {
    _customSubnet = customSubnet;
    return (await SharedPreferences.getInstance())
        .setString(_customSubnetKey, _customSubnet);
  }

  Future<void> load() async {
    debugPrint("Fetching all app settings");
    _firstSubnet =
        (await SharedPreferences.getInstance()).getInt(_firstSubnetKey) ??
            _firstSubnet;
    debugPrint("First subnet : $_firstSubnet");

    _lastSubnet =
        (await SharedPreferences.getInstance()).getInt(_lastSubnetKey) ??
            _lastSubnet;
    debugPrint("Last subnet : $_lastSubnet");

    _socketTimeout =
        (await SharedPreferences.getInstance()).getInt(_socketTimeoutKey) ??
            _socketTimeout;
    debugPrint("Socket timeout : $_socketTimeout");

    _pingCount =
        (await SharedPreferences.getInstance()).getInt(_pingCountKey) ??
            _pingCount;
    debugPrint("Ping count : $_pingCount");

    _inAppInternet =
        (await SharedPreferences.getInstance()).getBool(_inAppInternetKey) ??
            _inAppInternet;
    debugPrint("In-App Internet : $_inAppInternet");

    _customSubnet =
        (await SharedPreferences.getInstance()).getString(_customSubnetKey) ??
            _customSubnet;
    debugPrint("Custom Subnet : $_customSubnet");
  }
}
