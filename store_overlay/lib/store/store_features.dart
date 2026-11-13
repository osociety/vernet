// The store_overlay copies of this file and inline_adaptive_banner.dart carry
// the SDKs. The committed versions under lib/store/ are the inert ones.
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';

/// Initializes the Mobile Ads SDK. Called before `runApp`.
Future<void> initializeStoreSdk() => MobileAds.instance.initialize();

/// Asks Play for an in-app review, if the user is eligible.
Future<void> requestStoreReview() async {
  // Enable iOS after the Apple Store review flow is configured.
  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  } catch (error) {
    debugPrint('Unable to request in-app review: $error');
  }
}

/// Opens the Play listing for the app.
Future<void> openStoreListing() async {
  try {
    await InAppReview.instance.openStoreListing();
  } catch (error) {
    debugPrint('Unable to open the store listing: $error');
  }
}
