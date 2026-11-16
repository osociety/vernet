import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/utils/localization.dart';

import '../helpers/test_helpers.dart';

void main() {
  testWidgets('a non-English locale reaches the widget tree', (tester) async {
    await tester.pumpWidget(
      wrapWithLocalizations(
        locale: const Locale('de'),
        child: Builder(
          builder: (context) => Text(context.l10n.scanHistoryEmptyPlaceholder),
        ),
      ),
    );

    expect(
      find.text(
        'Noch keine früheren Scans.\n'
        'Führe einen Scan aus, um seinen Bericht hier zu sehen.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('English is what a device with no override renders',
      (tester) async {
    await tester.pumpWidget(
      wrapWithLocalizations(
        child:
            Builder(builder: (context) => Text(context.l10n.hostScanPageTitle)),
      ),
    );

    expect(find.text('Find devices'), findsOneWidget);
  });
}
