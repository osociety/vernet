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
      : _isp = json['isp'] as String,
        _ip = json['ip'] as String,
        _ipType = json['type'] as String,
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
      : _country = json['country'] as String,
        _region = json['region'] as String,
        _city = json['city'] as String,
        _lat = json['latitude'] as String,
        _lng = json['longitude'] as String,
        _flagUrl = json['country_flag'] as String;
}
