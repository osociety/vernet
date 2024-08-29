import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vernet/ui/external_link_dialog.dart';

Future<void> launchURL(String url) async => await canLaunchUrlString(url)
    ? await launchUrlString(url)
    : throw 'Could not launch $url';

Future<void> launchURLWithWarning(BuildContext context, String url) {
  return showAdaptiveDialog(
    context: context,
    builder: (context) => ExternalLinkWarningDialog(
      link: url,
    ),
  );
}

Future<void> storeCurrentScanId(int scanId) async {
  (await SharedPreferences.getInstance()).setInt('CurrentScanIDKey', scanId);
}

Future<int?> getCurrentScanId() async {
  return (await SharedPreferences.getInstance()).getInt('CurrentScanIDKey');
}
