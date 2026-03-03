import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/providers/internet_provider.dart';

void main() {
  group('InternetProvider', () {
    test('fromMap parses provider and location correctly', () {
      final json = <String, dynamic>{
        'isp': 'Test ISP',
        'ip': '1.2.3.4',
        'type': 'IPv4',
        'country': 'Testland',
        'region': 'Region',
        'city': 'City',
        'latitude': '10.0',
        'longitude': '20.0',
        'country_flag': 'https://example.com/flag.png',
      };

      final provider = InternetProvider.fromMap(json);

      expect(provider.isp, 'Test ISP');
      expect(provider.ip, '1.2.3.4');
      expect(provider.ipType, 'IPv4');
      expect(provider.location.address, 'City, Region, Testland');
      expect(provider.location.lat, '10.0');
      expect(provider.location.lng, '20.0');
      expect(provider.location.flagUrl, 'https://example.com/flag.png');
    });
  });
}
