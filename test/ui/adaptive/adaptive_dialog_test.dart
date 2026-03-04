import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';

void main() {
  testWidgets('AdaptiveDialog shows AlertDialog on non-iOS', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AdaptiveDialog(
                      title: Text('T'),
                      content: Text('C'),
                      actions: [],
                    ),
                  );
                },
                child: const Text('open'),
              );
            }),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (Platform.isIOS || Platform.isMacOS) {
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    } else {
      expect(find.byType(AlertDialog), findsOneWidget);
    }
    expect(find.text('T'), findsOneWidget);
  });
}
