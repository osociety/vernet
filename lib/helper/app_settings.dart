import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();

  static const String _lastSubnetKey = 'AppSettings-LAST_SUBNET';
  static const String _firstSubnetKey = 'AppSettings-FIRST_SUBNET';
  static const String _socketTimeoutKey = 'AppSettings-SOCKET_TIMEOUT';
  static const String _pingCountKey = 'AppSettings-PING_COUNT';
  int _firstSubnet = 1;
  int _lastSubnet = 254;
  int _socketTimeout = 500;
  int _pingCount = 5;

  static final AppSettings _instance = AppSettings._();

  static AppSettings get instance => _instance;
  int get firstSubnet => _firstSubnet;
  int get lastSubnet => _lastSubnet;
  int get socketTimeout => _socketTimeout;
  int get pingCount => _pingCount;

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

  Future<void> load() async {
    _firstSubnet =
        (await SharedPreferences.getInstance()).getInt(_firstSubnetKey) ??
            _firstSubnet;

    _lastSubnet =
        (await SharedPreferences.getInstance()).getInt(_lastSubnetKey) ??
            _lastSubnet;

    _socketTimeout =
        (await SharedPreferences.getInstance()).getInt(_socketTimeoutKey) ??
            _socketTimeout;

    _pingCount =
        (await SharedPreferences.getInstance()).getInt(_pingCountKey) ??
            _pingCount;
  }
}
