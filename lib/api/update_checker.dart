import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> _checkUpdates(String v) async {
  var url = Uri.parse(
      'https://api.github.com/repos/git-elliot/vernet/tags?per_page=1');
  var response = await http.get(url);
  if (response.statusCode == HttpStatus.ok) {
    List<dynamic> res = jsonDecode(response.body) as List<dynamic>;
    debugPrint(res.toString());
    if (res.length > 0) {
      String tag = res[0]["name"] as String;
      if (tag.contains('v')) {
        tag = tag.substring(1);
      }
      String tempV = v;
      if (tempV.contains('-store')) {
        List<String> sp = tempV.split('-store');
        tempV = sp[0] + sp[1];
      }
      debugPrint("tag: $tag , v: $tempV");
      return tempV.compareTo(tag) < 0;
    }
  }
  return false;
}

void _launchURL(String url) async =>
    await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';

Future<void> checkForUpdates(BuildContext context,
    {bool showIfNoUpdate = false}) async {
  try {
    var info = await PackageInfo.fromPlatform();
    String v = info.version + '+' + info.buildNumber;
    bool available = await compute(_checkUpdates, v);
    ScaffoldMessenger.of(context).clearSnackBars();
    Widget? content;
    SnackBarAction? action;
    if (available) {
      content = Text('There is an update available');
      action = SnackBarAction(
          label: 'Update',
          onPressed: () {
            _navigateToStore();
          });
    } else {
      if (showIfNoUpdate) {
        content = Text('No updates found');
      }
    }
    if (ScaffoldMessenger.of(context).mounted && content != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: content,
        action: action,
      ));
    }
  } catch (e) {
    debugPrint('unable to check for updates');
  }
}

_navigateToStore() async {
  String url = 'https://github.com/git-elliot/vernet/releases/latest';
  if (Platform.isAndroid) {
    if ((await PackageInfo.fromPlatform()).version.contains('store')) {
      //Goto playstore
      url =
          'https://play.google.com/store/apps/details?id=org.fsociety.vernet.store';
    }
  }
  _launchURL(url);
}
