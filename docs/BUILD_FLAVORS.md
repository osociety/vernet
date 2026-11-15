# Android build flavors

Back to [Vernet](../README.md).

Android is built in three flavors, and they differ in behavior, not only in id.

| Flavor | Ships to | Behavior |
|--------|----------|----------|
| `dev` | GitHub releases | Ad-free, checks GitHub for a newer release at startup. |
| `fdroid` | F-Droid | Ad-free and makes no GitHub request at all: no update check on startup and no update tile in Settings. |
| `store` | Google Play (`org.fsociety.vernet.store`) | Ad-free build plus AdMob banners and the in-app review prompt. |

One release run publishes all of them: the `dev` APKs go on the GitHub release,
the `store` bundle goes to the Play beta track next to the Snap Store upload,
and F-Droid builds the `fdroid` flavor from this repository itself.

`lib/values/build_flavor.dart` reads the `FLUTTER_APP_FLAVOR` define that
`flutter build` and `flutter test` inject whenever `--flavor` is passed. Because
the gate is a compile-time constant, the disabled code is removed from the
binary rather than merely hidden at runtime. Anything built without a flavor —
the snap, the desktop runners, iOS — gets the ad-free side with the update
check.

All three flavors are tested, not just built: the Android integration workflow
runs the full suite as a `dev` / `fdroid` / `store` matrix, and `--flavor` is the
only way to reach those branches, because `flutter test` refuses a
`--dart-define` of a name the tool reserves for itself. The `store` leg builds
the committed tree, so it exercises the gating against the inert `lib/store/`
seam rather than AdMob.

```bash
./scripts/android_integration fdroid   # dev, fdroid or store
```

The `store` flavor is the only build carrying proprietary plugins, and they are
deliberately absent from the committed `pubspec.yaml`: F-Droid rejects a non-free
dependency there. `dart run scripts/build_store.dart` applies `store_overlay/`
(the ad banner, the Play SDK calls, and the two dependencies), builds the
bundle, then restores the tree byte for byte — including `pubspec.lock`, which
F-Droid enforces.

## Publishing to F-Droid

You can follow this guide to publish your app to F-Droid —
https://op3nsoc13ty.blogspot.com/2021/06/publish-your-first-flutter-app-to-fdroid.html
