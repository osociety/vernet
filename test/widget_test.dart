import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/globals.dart' as globals;

Future<void> main() async {
  globals.testingActive = true;
  group('Widget test', () {
    testWidgets('My first widget test', (tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp(false));
    });
  });
}
