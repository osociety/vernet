import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';

void main() {
  Widget createWidgetUnderTest({
    Widget? title,
    Widget? content,
    List<Widget> actions = const [],
    VoidCallback? onClose,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AdaptiveDialog(
                    title: title,
                    content: content,
                    actions: actions,
                    onClose: onClose,
                  ),
                );
              },
              child: const Text('open'),
            );
          }),
        ),
      ),
    );
  }

  testWidgets('AdaptiveDialog shows AlertDialog on Android', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      title: const Text('T'),
      content: const Text('C'),
      platform: TargetPlatform.android,
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('AdaptiveDialog shows CupertinoAlertDialog on iOS',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      title: const Text('T'),
      content: const Text('C'),
      platform: TargetPlatform.iOS,
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('AdaptiveDialog default Close button pops navigator',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveDialog), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveDialog), findsNothing);
  });

  testWidgets('AdaptiveDialog custom onClose is called', (tester) async {
    bool closed = false;
    await tester.pumpWidget(createWidgetUnderTest(onClose: () {
      closed = true;
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('AdaptiveDialog custom actions are rendered and clickable',
      (tester) async {
    bool actionCalled = false;
    await tester.pumpWidget(createWidgetUnderTest(
      actions: [
        TextButton(
          onPressed: () => actionCalled = true,
          child: const Text('Action1'),
        ),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Action1'), findsOneWidget);

    await tester.tap(find.text('Action1'));
    await tester.pumpAndSettle();

    expect(actionCalled, isTrue);
  });
}
