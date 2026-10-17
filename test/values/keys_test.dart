import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/keys.dart';

void main() {
  test('WidgetKey enum provides ValueKey and is comparable', () {
    final list = <WidgetKey>[
      WidgetKey.ping,
      WidgetKey.homeButton,
      WidgetKey.appleChip
    ];
    list.sort();
    // After sorting by value, ensure ValueKey value matches
    for (final k in list) {
      expect(k.key, isA<ValueKey>());
      expect(k.key.value, isA<String>());
    }
    // compareTo consistency
    expect(WidgetKey.appleChip.compareTo(WidgetKey.homeButton), lessThan(0));
    expect(WidgetKey.pingSummaryMin.value, 'pingSummaryMin');
    expect(WidgetKey.pingSummaryAvg.value, 'pingSummaryAvg');
    expect(WidgetKey.pingSummaryMax.value, 'pingSummaryMax');
    expect(WidgetKey.pingSummaryStdDev.value, 'pingSummaryStdDev');
    expect(WidgetKey.pingSummaryPacketLoss.value, 'pingSummaryPacketLoss');
  });
}
