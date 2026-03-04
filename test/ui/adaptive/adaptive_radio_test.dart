import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';

void main() {
  testWidgets('AdaptiveRadioButton builds and changes value', (tester) async {
    String? groupValue = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveRadioButton<String>(
            value: 'b',
            groupValue: groupValue,
            onChanged: (v) {
              groupValue = v;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    if (Platform.isIOS || Platform.isMacOS) {
      expect(find.byType(CupertinoRadio<String>), findsOneWidget);
    } else {
      expect(find.byType(Radio<String>), findsOneWidget);
    }
  });
}
