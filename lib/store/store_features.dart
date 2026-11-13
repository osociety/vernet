// Capabilities only the Google Play build has.
//
// These are the committed, inert implementations. `store_overlay/` replaces
// this file with versions backed by `google_mobile_ads` and `in_app_review`,
// which are dependencies of the Play build only — so no flavor but `store`
// links either SDK. See `store_overlay/README.md`.

/// Initializes the SDK a banner needs. Called before `runApp`.
Future<void> initializeStoreSdk() async {}

/// Asks Play for an in-app review, if the user is eligible.
Future<void> requestStoreReview() async {}

/// Opens the Play listing for the app.
Future<void> openStoreListing() async {}
