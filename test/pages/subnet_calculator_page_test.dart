import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/subnet_calculator_page.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/utils/app_strings.dart';

import '../helpers/test_helpers.dart';

/// Each result row carries a label, a copy tooltip and a value. Only the value
/// belongs on screen, and a row that grows a field shifts the record indices
/// that pick them — which this test caught once already.
void main() {
  final l10n = l10nEn();

  Future<void> calculate(
    WidgetTester tester,
    String input, {
    Locale locale = const Locale('en'),
  }) async {
    final strings = stringsForLocale(locale);
    await tester.pumpWidget(
      wrapWithLocalizations(
          child: const SubnetCalculatorPage(), locale: locale),
    );
    await tester.enterText(find.byType(TextField), input);
    await tester.tap(find.text(strings.subnetCalcRun));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the computed values and not the copy tooltips',
      (tester) async {
    await calculate(tester, '192.168.1.42/24');

    expect(find.text('192.168.1.0/24'), findsOneWidget);
    expect(find.text('192.168.1.0'), findsOneWidget);
    expect(find.text('255.255.255.0'), findsOneWidget);
    expect(find.text('192.168.1.255'), findsOneWidget);
    expect(find.text('256'), findsOneWidget);
    expect(find.text(l10n.subnetCalcCopySubnetMask), findsNothing);
    expect(find.text(l10n.subnetCalcCopyAddressCount), findsNothing);
  });

  testWidgets('drops the broadcast row for IPv6', (tester) async {
    await calculate(tester, '2001:db8::1/64');

    expect(find.text('ffff:ffff:ffff:ffff::'), findsOneWidget);
    expect(find.text('2001:db8::ffff:ffff:ffff:ffff'), findsOneWidget);
    expect(find.text('18446744073709551616'), findsOneWidget);
    expect(find.text(l10n.subnetCalcBroadcastAddress), findsNothing);
  });

  testWidgets('reports a rejected address in the active locale',
      (tester) async {
    LocaleProvider.active = const Locale('de');
    addTearDown(() => LocaleProvider.active = null);

    await calculate(tester, 'not-an-ip/24', locale: const Locale('de'));

    expect(find.text(l10nDe().subnetCalcErrorAddressInvalid), findsOneWidget);
    expect(find.text(l10n.subnetCalcErrorAddressInvalid), findsNothing);
  });
}
