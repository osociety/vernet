import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';

Future<void> main() async {
  group('Widget test', () {
    testWidgets('My first widget test', (tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp(false));
    });
  });
}
