import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _MAX_NETWORK_SIZE_KEY = 'AppSettings-MAX_NETWORK_SIZE';
  static const String _SOCKET_TIMEOUT_KEY = 'AppSettings-SOCKET_TIMEOUT';
  static const String _PING_COUNT_KEY = 'AppSettings-PING_COUNT';
  int _maxNetworkSize = 50;
  int _socketTimeout = 500;
  int _pingCount = 5;

  static AppSettings _instance = AppSettings._();

  AppSettings._();

  static AppSettings get instance => _instance;
  int get maxNetworkSize => _maxNetworkSize;
  int get socketTimeout => _socketTimeout;
  int get pingCount => _pingCount;

  Future<bool> setMaxNetworkSize(int maxNetworkSize) async {
    _maxNetworkSize = maxNetworkSize;
    return (await SharedPreferences.getInstance())
        .setInt(_MAX_NETWORK_SIZE_KEY, _maxNetworkSize);
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
    _maxNetworkSize =
        (await SharedPreferences.getInstance()).getInt(_MAX_NETWORK_SIZE_KEY) ??
            _maxNetworkSize;

    _socketTimeout =
        (await SharedPreferences.getInstance()).getInt(_SOCKET_TIMEOUT_KEY) ??
            _socketTimeout;

    _pingCount =
        (await SharedPreferences.getInstance()).getInt(_PING_COUNT_KEY) ??
            _pingCount;
  }
}
