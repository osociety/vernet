import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/api/isp_loader.dart';
import 'package:vernet/providers/internet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ISPLoader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns InternetProvider in debug mode using bundled asset',
        () async {
      final loader = ISPLoader();

      final InternetProvider? provider = await loader.load();

      expect(provider, isNotNull);
      expect(provider!.isp, isNotEmpty);
      expect(provider.ip, isNotEmpty);
      expect(provider.location.address, isNotEmpty);
    });
  });
}
