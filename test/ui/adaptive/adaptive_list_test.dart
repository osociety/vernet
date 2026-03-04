import 'dart:io';

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
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    if (Platform.isIOS || Platform.isMacOS) {
      expect(find.byType(CupertinoListTile), findsOneWidget);
    } else {
      expect(find.byType(ListTile), findsOneWidget);
    }
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('AdaptiveListTile onTap is triggered', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: const Text('TapMe'),
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('TapMe'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
