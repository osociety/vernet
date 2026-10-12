import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vernet/pages/subnet_calculator_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calculates and displays IPv4 subnet details', (tester) async {
    await _openCalculator(tester);
    await _calculate(tester, '192.168.1.42/24');

    expect(find.text('192.168.1.0/24'), findsOneWidget);
    expect(find.text('255.255.255.0'), findsOneWidget);
    expect(find.text('192.168.1.255'), findsOneWidget);
    expect(find.text('192.168.1.1'), findsOneWidget);
    expect(find.text('192.168.1.254'), findsOneWidget);
    expect(find.text('256'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('calculates and displays IPv6 subnet details', (tester) async {
    await _openCalculator(tester);
    await _calculate(tester, '2001:db8::1/64');

    expect(find.text('2001:db8::/64'), findsOneWidget);
    expect(find.text('ffff:ffff:ffff:ffff::'), findsOneWidget);
    expect(find.text('2001:db8::ffff:ffff:ffff:ffff'), findsOneWidget);
    expect(find.text('18446744073709551616'), findsOneWidget);
    expect(find.text('Broadcast address'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows validation for invalid input', (tester) async {
    await _openCalculator(tester);
    await _calculate(tester, 'not-an-ip/24');
    expect(find.text('Enter a valid IPv4 or IPv6 address.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _openCalculator(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SubnetCalculatorPage()));
  await tester.pumpAndSettle();
  expect(find.text('IP subnet calculator'), findsOneWidget);
  expect(find.text('IP address / prefix'), findsOneWidget);
}

Future<void> _calculate(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField), input);
  await tester.pump();
  await tester.ensureVisible(find.text('Calculate'));
  await tester.tap(find.text('Calculate'));
  await tester.pumpAndSettle();
}
