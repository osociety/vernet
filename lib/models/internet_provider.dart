class InternetProvider {
  String _isp;
  Location _location;
  String get isp => _isp;
  Location get location => _location;
  InternetProvider.fromMap(Map<String, dynamic> json)
      : _isp = json['isp'],
        _location = Location.fromMap(json['location']);
}

class Location {
  String _country;
  String _region;
  String _city;
  double _lat;
  double _lng;

  String get address => _city + ', ' + _region + ', ' + _country;
  double get lat => _lat;
  double get lng => _lng;

  Location.fromMap(Map<String, dynamic> json)
      : _country = json['country'],
        _region = json['region'],
        _city = json['city'],
        _lat = json['lat'],
        _lng = json['lng'];
}
