import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/utils_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UtilsHelper', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('storeCurrentScanId and getCurrentScanId round trip', () async {
      await storeCurrentScanId(42);
      final id = await getCurrentScanId();

      expect(id, 42);
    });
  });
}


