class InternetProvider {
  String _isp;
  String _ip;
  String _ipType;
  Location _location;

  String get isp => _isp;
  Location get location => _location;
  String get ip => _ip;
  String get ipType => _ipType;

  InternetProvider.fromMap(Map<String, dynamic> json)
      : _isp = json['isp'],
        _ip = json['ip'],
        _ipType = json['type'],
        _location = Location.fromMap(json);
}

class Location {
  String _country;
  String _region;
  String _city;
  String _lat;
  String _lng;
  String _flagUrl;

  String get address => _city + ', ' + _region + ', ' + _country;
  String get lat => _lat;
  String get lng => _lng;
  String get flagUrl => _flagUrl;

  Location.fromMap(Map<String, dynamic> json)
      : _country = json['country'],
        _region = json['region'],
        _city = json['city'],
        _lat = json['latitude'],
        _lng = json['longitude'],
        _flagUrl = json['country_flag'];
}
