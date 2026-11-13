# store_overlay

Files that `scripts/build_store.dart` copies over the tree to turn this
checkout into the Google Play build. Nothing here is part of a normal build:
`analysis_options.yaml` excludes the directory, so `flutter analyze` and
`flutter test` never see the ad SDK imports.

| Overlaid file | Why the committed version differs |
| --- | --- |
| `lib/store/store_features.dart` | Real `MobileAds` and `InAppReview` calls. |
| `lib/store/inline_adaptive_banner.dart` | Real AdMob inline adaptive banner, plus the ad unit ids. |
| `pubspec_additions.yaml` | The two plugins spliced into `pubspec.yaml`'s `dependencies:`. |

The split exists because F-Droid reads `pubspec.yaml`: a `google_mobile_ads`
dependency there is a `NonFreeDep` plus `Ads` anti-feature and the app is
rejected. So the committed pubspec stays ad-free, `lib/store/` keeps inert
stubs that every other flavor compiles, and only this overlay carries the SDK.
Call sites in `lib/pages/` are shared — they use the stub API, and
`kStoreBannerRows` from `lib/values/build_flavor.dart` decides whether a list
also carries a banner row.

`android/app/src/store/AndroidManifest.xml` is the Android-side half of this:
AGP merges it for the `store` flavor only, so the AdMob app id and the `AD_ID`
permission never reach another flavor.

## Editing rules

- `StoreAdSlot` lives in `lib/store/store_ad_slot.dart`, outside the overlay,
  so a new slot breaks the store build loudly instead of silently rendering
  nothing.
- An overlay file must keep the public API of its committed counterpart, and
  both must stay in `scripts/build_store.dart`'s file list.
- Never add a dependency to `pubspec_additions.yaml` that a non-store flavor
  would link, and never import these packages from anywhere but `lib/store/`.
