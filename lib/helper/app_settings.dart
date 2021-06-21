import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _LAST_SUBNET_KEY = 'AppSettings-LAST_SUBNET';
  static const String _FIRST_SUBNET_KEY = 'AppSettings-FIRST_SUBNET';
  static const String _SOCKET_TIMEOUT_KEY = 'AppSettings-SOCKET_TIMEOUT';
  static const String _PING_COUNT_KEY = 'AppSettings-PING_COUNT';
  int _firstSubnet = 1;
  int _lastSubnet = 30;
  int _socketTimeout = 500;
  int _pingCount = 5;

  static AppSettings _instance = AppSettings._();

  AppSettings._();

  static AppSettings get instance => _instance;
  int get firstSubnet => _firstSubnet;
  int get lastSubnet => _lastSubnet;
  int get socketTimeout => _socketTimeout;
  int get pingCount => _pingCount;

  Future<bool> setFirstSubnet(int firstSubnet) async {
    _firstSubnet = firstSubnet;
    return (await SharedPreferences.getInstance())
        .setInt(_FIRST_SUBNET_KEY, _firstSubnet);
  }

  Future<bool> setLastSubnet(int lastSubnet) async {
    _lastSubnet = lastSubnet;
    return (await SharedPreferences.getInstance())
        .setInt(_LAST_SUBNET_KEY, _lastSubnet);
  }

  Future<bool> setSocketTimeout(int socketTimeout) async {
    _socketTimeout = socketTimeout;
    return (await SharedPreferences.getInstance())
        .setInt(_SOCKET_TIMEOUT_KEY, _socketTimeout);
  }

  Future<bool> setPingCount(int pingCount) async {
    _pingCount = pingCount;
    return (await SharedPreferences.getInstance())
        .setInt(_PING_COUNT_KEY, _pingCount);
  }

  Future<void> load() async {
    _firstSubnet =
        (await SharedPreferences.getInstance()).getInt(_FIRST_SUBNET_KEY) ??
            _firstSubnet;

    _lastSubnet =
        (await SharedPreferences.getInstance()).getInt(_LAST_SUBNET_KEY) ??
            _lastSubnet;

    _socketTimeout =
        (await SharedPreferences.getInstance()).getInt(_SOCKET_TIMEOUT_KEY) ??
            _socketTimeout;

    _pingCount =
        (await SharedPreferences.getInstance()).getInt(_PING_COUNT_KEY) ??
            _pingCount;
  }
}
