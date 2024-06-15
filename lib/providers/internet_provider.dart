class InternetProvider {
  InternetProvider.fromMap(Map<String, dynamic> json)
      : _isp = json['isp'] as String,
        _ip = json['ip'] as String,
        _ipType = json['type'] as String,
        _location = Location.fromMap(json);

  final String _isp;
  final String _ip;
  final String _ipType;
  final Location _location;

  String get isp => _isp;
  Location get location => _location;
  String get ip => _ip;
  String get ipType => _ipType;
}

class Location {
  Location.fromMap(Map<String, dynamic> json)
      : _country = json['country'] as String,
        _region = json['region'] as String,
        _city = json['city'] as String,
        _lat = json['latitude'] as String,
        _lng = json['longitude'] as String,
        _flagUrl = json['country_flag'] as String;

  final String _country;
  final String _region;
  final String _city;
  final String _lat;
  final String _lng;
  final String _flagUrl;

  String get address => '$_city, $_region, $_country';
  String get lat => _lat;
  String get lng => _lng;
  String get flagUrl => _flagUrl;
}
