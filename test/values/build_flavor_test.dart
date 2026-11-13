import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/build_flavor.dart';

void main() {
  group('build flavor gates', () {
    // `FLUTTER_APP_FLAVOR` is reserved by the Flutter tool — it is only ever
    // set from `--flavor`, and `flutter test` rejects a `--dart-define` for it.
    // So this suite holds the flavorless state (snap, desktop runners, iOS and
    // the analyzer), and the flavored branches are proven against a release
    // binary rather than asserted here:
    //
    //   flutter build apk --flavor fdroid --release
    //   unzip -p app-fdroid-release.apk lib/arm64-v8a/libapp.so \
    //     | strings | grep -c api.github.com
    //
    // measured on the 1.6.1 work: 0 in fdroid, 1 in dev, because the updater is
    // a compile-time constant at both call sites and tree-shaken out of the
    // fdroid snapshot.
    test('the committed tree is ad-free and still checks for updates', () {
      expect(appFlavor, isEmpty);
      expect(kStoreBuild, isFalse);
      expect(kStoreBannerRows, 0);
      expect(kUpdateChecksEnabled, isTrue);
    });
  });
}
