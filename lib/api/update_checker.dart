import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:external_app_launcher/external_app_launcher.dart';

Future<bool> _checkUpdates(String v) async {
  final Uri url = Uri.parse(
    'https://api.github.com/repos/git-elliot/vernet/tags?per_page=1',
  );
  final response = await http.get(url);
  if (response.statusCode == HttpStatus.ok) {
    final List<dynamic> res = jsonDecode(response.body) as List<dynamic>;
    if (res.isNotEmpty) {
      String tag = res[0]['name'] as String;
      if (tag.contains('v')) {
        tag = tag.substring(1);
      }
      String tempV = v;
      if (tempV.contains('-store')) {
        final List<String> sp = tempV.split('-store');
        tempV = sp[0] + sp[1];
      }
      return tempV.compareTo(tag) < 0;
    }
  }
  return false;
}

Future<void> checkForUpdates(
  BuildContext context, {
  bool showIfNoUpdate = false,
}) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final String v = '${info.version}+${info.buildNumber}';
    final bool available = await compute(_checkUpdates, v);
    ScaffoldMessenger.of(context).clearSnackBars();
    Widget? content;
    SnackBarAction? action;
    if (available) {
      content = const Text('There is an update available');
      action = SnackBarAction(
        label: 'Update',
        onPressed: () {
          _navigateToStore();
        },
      );
    } else {
      if (showIfNoUpdate) {
        content = const Text('No updates found');
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

Future<void> _navigateToStore() async {
  String url = 'https://github.com/git-elliot/vernet/releases/latest';
  final isFdroidInstalled = await LaunchApp.isAppInstalled(
    androidPackageName: 'org.fdroid.fdroid',
    iosUrlScheme: 'fdroid://',
  );

  if (Platform.isAndroid) {
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
  launchURL(url);
}
