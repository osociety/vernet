import 'dart:convert';
import 'dart:io';

import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/update_channel_dialog.dart';
import 'package:vernet/values/store_links.dart';

@visibleForTesting
Future<bool> checkUpdates(
  String v, {
  http.Client? client,
  Uri? url,
  bool beta = false,
}) async {
  final Uri target = url ?? releaseApiUrlFor(beta: beta);
  final c = client ?? http.Client();
  final response = await c.get(target);
  if (response.statusCode == HttpStatus.ok) {
    try {
      // Handle empty response body
      if (response.body.isEmpty) {
        return false;
      }

      final dynamic payload = jsonDecode(response.body);
      // The beta endpoint is a listing, so the newest entry has to be taken
      // out of it. `/releases/latest` answers with the release itself.
      final dynamic release = payload is List<dynamic>
          ? (payload.isEmpty ? null : payload.first)
          : payload;
      // Only the release-object shape is accepted. A `/tags` listing would
      // have no way to tell a beta tag from a stable one.
      if (release is! Map<String, dynamic>) return false;
      // A draft is never published, to beta testers or anyone else.
      if (release['draft'] == true) return false;
      // Every release this repo cuts starts life as a pre-release and is
      // promoted to stable by hand, so `/releases/latest` is the promoted one
      // and a pre-release in the listing is the current beta. Offering one to
      // a stable install is the bug that beta testers reported.
      if (release['prerelease'] == true && !beta) return false;
      final dynamic tagName = release['tag_name'];
      if (tagName is! String) return false;

      final remoteVersion = _versionParts(tagName);
      final installedVersion = _versionParts(v);
      if (remoteVersion == null || installedVersion == null) return false;

      return _compareVersions(installedVersion, remoteVersion) < 0;
    } catch (e) {
      // Handle JSON parsing errors gracefully
      return false;
    }
  }
  return false;
}

/// Which GitHub endpoint the channel is read from.
///
/// Stable asks for the newest non-draft, non-pre-release; beta asks for the
/// newest release of any kind.
@visibleForTesting
Uri releaseApiUrlFor({required bool beta}) => beta
    ? Uri.parse('$githubReleasesApiUrl?per_page=1')
    : Uri.parse(githubLatestReleaseApiUrl);

List<int>? _versionParts(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  // Store builds add `-store` to the version before PackageInfo's build
  // number is appended (for example `1.3.9-store+50`). Preserve that build
  // number when comparing with a release tag such as `v1.3.9+50`.
  normalized = normalized.replaceAll('-store', '');

  final match = RegExp(r'^(\d+(?:\.\d+)*)(?:\+(\d+))?$').firstMatch(normalized);
  if (match == null) return null;

  final parts = match.group(1)!.split('.').map(int.tryParse).toList();
  if (parts.any((part) => part == null)) return null;
  return <int>[...parts.cast<int>(), int.tryParse(match.group(2) ?? '0') ?? 0];
}

int _compareVersions(List<int> left, List<int> right) {
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final leftPart = index < left.length ? left[index] : 0;
    final rightPart = index < right.length ? right[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

// exposed for testing so we can inject a client or URL without running
// the compute helper.
Future<bool> checkUpdatesForTest(
  String v, {
  http.Client? client,
  Uri? url,
  bool beta = false,
}) {
  return checkUpdates(v, client: client, url: url, beta: beta);
}

/// `compute` accepts one message, so the version and the channel travel
/// together.
Future<bool> _checkUpdatesForChannel(Map<String, dynamic> args) => checkUpdates(
      args['version'] as String,
      beta: args['beta'] as bool,
    );

Future<void> checkForUpdates(
  BuildContext context, {
  bool showIfNoUpdate = false,
}) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final String v = '${info.version}+${info.buildNumber}';
    bool available = false;
    if (appSettings.inAppInternet) {
      available = await compute(
        _checkUpdatesForChannel,
        <String, dynamic>{'version': v, 'beta': appSettings.betaUpdates},
      );
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    Widget? content;
    SnackBarAction? action;
    if (available) {
      content = const Text('A newer version is available');
      action = SnackBarAction(
        label: 'Get update',
        onPressed: () {
          navigateToStore(context);
        },
      );
    } else {
      if (showIfNoUpdate) {
        content = const Text('You are using the latest version');
        if (!appSettings.inAppInternet) {
          content = const Text(
              'Allow internet access in Settings to check for updates.');
        }
      }
    }
    if (content != null) {
      messenger.showSnackBar(
        SnackBar(
          content: content,
          action: action,
        ),
      );
    }
  } catch (e) {
    debugPrint('unable to check for updates');
  }
}

/// Store releases trail the GitHub one, so the user is asked which to open.
Future<void> navigateToStore(BuildContext context) async {
  final store = await _storeRelease();
  if (!context.mounted) return;
  final channel =
      await UpdateChannelDialog.show(context, storeLabel: store?.label);
  if (!context.mounted) return;
  switch (channel) {
    case UpdateChannel.store:
      await store?.open(context);
    case UpdateChannel.github:
      await launchURLWithWarning(context, githubLatestReleaseUrl);
    case null:
      break;
  }
}

/// A store this platform publishes to, or null when it has none.
class _StoreRelease {
  const _StoreRelease(this.label, this.open);

  final String label;
  final Future<void> Function(BuildContext context) open;
}

Future<_StoreRelease?> _storeRelease() async {
  if (Platform.isWindows) {
    return _StoreRelease(
      'Microsoft Store',
      (context) => launchURLWithWarning(context, microsoftStoreListingUrl),
    );
  }
  if (Platform.isLinux) {
    return _StoreRelease(
      'Snap Store',
      (context) => launchURLWithWarning(context, snapStoreListingUrl),
    );
  }
  if (!Platform.isAndroid) {
    return null;
  }
  if ((await PackageInfo.fromPlatform()).version.contains('store')) {
    return _StoreRelease(
      'Play Store',
      (context) => launchURLWithWarning(context, playStoreListingUrl),
    );
  }
  final fdroidInstalled = await LaunchApp.isAppInstalled(
    androidPackageName: 'org.fdroid.fdroid',
    iosUrlScheme: 'fdroid://',
  );
  // F-Droid tracks the repo itself, so the app is opened rather than a link.
  return fdroidInstalled == true
      ? const _StoreRelease('F-Droid', _openFdroidApp)
      : null;
}

Future<void> _openFdroidApp(BuildContext context) async {
  await LaunchApp.openApp(
    androidPackageName: 'org.fdroid.fdroid',
    iosUrlScheme: 'fdroid://',
    appStoreLink: 'itms-apps://itunes.apple.com/',
    openStore: false,
  );
}
