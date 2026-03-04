import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/consent_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsentLoader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false when nothing stored', () async {
      final shown = await ConsentLoader.isConsentPageShown();
      expect(shown, isFalse);
    });

    test('persists and returns true', () async {
      final result = await ConsentLoader.setConsentPageShown(true);
      expect(result, isTrue);

      final shown = await ConsentLoader.isConsentPageShown();
      expect(shown, isTrue);
    });

    test('can toggle back to false', () async {
      await ConsentLoader.setConsentPageShown(true);
      await ConsentLoader.setConsentPageShown(false);

      final shown = await ConsentLoader.isConsentPageShown();
      expect(shown, isFalse);
    });
  });
}
