import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

void main() {
  testWidgets('AdaptiveListTile renders ListTile on non-iOS platforms',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Hello'),
              subtitle: Text('Subtitle'),
              leading: Icon(Icons.add),
              trailing: Icon(Icons.chevron_right),
              platform: 'android',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('AdaptiveListTile renders CupertinoListTile on iOS',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Hello'),
              subtitle: Text('Subtitle'),
              leading: Icon(Icons.add),
              trailing: Icon(Icons.chevron_right),
              platform: 'ios',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CupertinoListTile), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('AdaptiveListTile onTap and onLongPress are triggered',
      (tester) async {
    var tapped = false;
    var longPressed = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: const Text('ActionMe'),
              platform: 'android',
              onTap: () {
                tapped = true;
              },
              onLongPress: () {
                longPressed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('ActionMe'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    await tester.longPress(find.text('ActionMe'));
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
  });

  testWidgets('AdaptiveListTile respects dense and contentPadding',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Dense'),
              dense: true,
              contentPadding: EdgeInsets.all(20),
              platform: 'android',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final listTile = tester.widget<ListTile>(find.byType(ListTile));
    expect(listTile.dense, isTrue);
    expect(listTile.contentPadding, const EdgeInsets.all(20));
  });
}
