import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/ui/timestamp_chip.dart';

import '../helpers/test_helpers.dart';

/// The chip is where a hard-coded date format hides: it has to render the clock
/// of the selected locale rather than the machine's.
void main() {
  final stamp = DateTime(2026, 3, 14, 15, 9);

  Future<void> pumpChip(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) =>
      tester.pumpWidget(
        wrapWithLocalizations(
            child: TimestampChip(timestamp: stamp), locale: locale),
      );

  testWidgets('renders the timestamp of the active locale', (tester) async {
    await pumpChip(tester);
    expect(find.text(formatTimestamp(l10nEn(), stamp)), findsOneWidget);

    await pumpChip(tester, locale: const Locale('de'));
    expect(find.text(formatTimestamp(l10nDe(), stamp)), findsOneWidget);
  });

  testWidgets('leaves the English am/pm marker behind in German',
      (tester) async {
    await pumpChip(tester);
    expect(find.textContaining('PM'), findsOneWidget);

    await pumpChip(tester, locale: const Locale('de'));
    expect(find.textContaining('PM'), findsNothing);
  });
}
