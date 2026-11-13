import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/store/inline_adaptive_banner.dart';
import 'package:vernet/store/store_ad_slot.dart';
import 'package:vernet/store/store_features.dart';
import 'package:vernet/values/build_flavor.dart';

void main() {
  group('committed store seam', () {
    // These hold for the tree F-Droid, the snap and the GitHub APK build. Once
    // scripts/build_store.dart has applied store_overlay/, lib/store/ holds the
    // AdMob and InAppReview implementations instead, and only the flavor
    // constants still apply.
    const overlaid = kStoreBuild;

    testWidgets('banner collapses to nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineAdaptiveBanner(slot: StoreAdSlot.hostScan),
          ),
        ),
      );

      expect(find.byType(InlineAdaptiveBanner), findsOneWidget);
      expect(tester.getSize(find.byType(InlineAdaptiveBanner)), Size.zero);
    }, skip: overlaid);

    test('feature calls complete without an SDK', () async {
      await initializeStoreSdk();
      await requestStoreReview();
      await openStoreListing();
    }, skip: overlaid ? 'store_overlay replaces these calls' : false);
  });
}
