import 'dart:convert';
import 'dart:io';

import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/helper/utils_helper.dart';

import 'package:vernet/main.dart';

@visibleForTesting
Future<bool> checkUpdates(
  String v, {
  http.Client? client,
  Uri? url,
}) async {
  final Uri target = url ??
      Uri.parse(
        'https://api.github.com/repos/osociety/vernet/releases/latest',
      );
  final c = client ?? http.Client();
  final response = await c.get(target);
  if (response.statusCode == HttpStatus.ok) {
    try {
      // Handle empty response body
      if (response.body.isEmpty) {
        return false;
      }

      final dynamic payload = jsonDecode(response.body);
      // Accept the old tags-array shape as well, so existing clients and
      // callers that provide a tags URL continue to work.
      final dynamic tagName = payload is List
          ? (payload.isEmpty ? null : payload.first['name'])
          : payload is Map<String, dynamic>
              ? payload['tag_name']
              : null;
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

List<int>? _versionParts(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  // Store builds add `-store` to the version before PackageInfo's build
  // number is appended (for example `1.3.9-store+50`). Preserve that build
  // number when comparing with a release tag such as `v1.3.9+50`.
  normalized = normalized.replaceAll('-store', '');

  final match = RegExp(r'^(\d+(?:\.\d+)*)(?:\+(\d+))?$')
      .firstMatch(normalized);
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
}) {
  return checkUpdates(v, client: client, url: url);
}

Future<void> checkForUpdates(
  BuildContext context, {
  bool showIfNoUpdate = false,
}) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final String v = '${info.version}+${info.buildNumber}';
    bool available = false;
    if (appSettings.inAppInternet) {
      available = await compute(checkUpdates, v);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
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
    if (ScaffoldMessenger.of(context).mounted && content != null) {
      ScaffoldMessenger.of(context).showSnackBar(
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

Future<void> navigateToStore(BuildContext context) async {
  String url = 'https://github.com/osociety/vernet/releases/latest';

  if (Platform.isAndroid) {
    final isFdroidInstalled = await LaunchApp.isAppInstalled(
      androidPackageName: 'org.fdroid.fdroid',
      iosUrlScheme: 'fdroid://',
    );

    if ((await PackageInfo.fromPlatform()).version.contains('store')) {
      //Goto playstore
      url =
          'https://play.google.com/store/apps/details?id=org.fsociety.vernet.store';
    } else if (isFdroidInstalled == true) {
      await LaunchApp.openApp(
        androidPackageName: 'org.fdroid.fdroid',
        iosUrlScheme: 'fdroid://',
        appStoreLink: 'itms-apps://itunes.apple.com/',
        openStore: false,
      );
      return;
    }
  }
  launchURLWithWarning(context, url);
}
