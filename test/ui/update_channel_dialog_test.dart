import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/update_channel_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
  }

  // The choice future resolves when a button is tapped, so tests hold it
  // instead of awaiting it where the dialog opens.
  Future<UpdateChannel?> openDialog(
    WidgetTester tester, {
    String? storeLabel,
  }) {
    return UpdateChannelDialog.show(
      tester.element(find.byType(Scaffold)),
      storeLabel: storeLabel,
    );
  }

  group('UpdateChannelDialog', () {
    testWidgets('names the store and offers both channels', (tester) async {
      await pumpShell(tester);
      final choice = openDialog(tester, storeLabel: 'Play Store');
      await tester.pumpAndSettle();

      expect(find.text('Where to get the update'), findsOneWidget);
      expect(
          find.textContaining('fastest way to get features'), findsOneWidget);
      expect(find.textContaining('can take a few days'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Play Store'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);

      await tester.tap(find.text('Play Store'));
      await tester.pumpAndSettle();
      expect(await choice, UpdateChannel.store);
    });

    testWidgets('offers GitHub alone where no store build exists',
        (tester) async {
      await pumpShell(tester);
      final choice = openDialog(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('reviews it again'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);

      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      expect(await choice, UpdateChannel.github);
    });

    testWidgets('closing answers nothing', (tester) async {
      await pumpShell(tester);
      final choice = openDialog(tester, storeLabel: 'Snap Store');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await choice, isNull);
    });
  });
}
