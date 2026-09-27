import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vernet/pages/host_scan_page/widgets/inline_adaptive_banner.dart';

void main() {
  const banner = InlineAdaptiveBanner(adUnitId: 'test-ad-unit');

  testWidgets('renders nothing on unsupported platforms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: const Scaffold(body: banner),
      ),
    );

    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not request an ad with unbounded width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const Scaffold(
          body: UnconstrainedBox(child: banner),
        ),
      ),
    );

    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not request an ad with zero width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const Scaffold(
          body: SizedBox(width: 0, child: banner),
        ),
      ),
    );

    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
