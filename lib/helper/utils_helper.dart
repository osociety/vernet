import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vernet/ui/external_link_dialog.dart';

Future<void> launchURL(String url) async => await canLaunchUrlString(url)
    ? await launchUrlString(url)
    : throw 'Could not launch $url';

Future<void> launchURLWithWarning(BuildContext context, String url) {
  return showDialog(
    context: context,
    builder: (context) => ExternalLinkWarningDialog(
      link: url,
    ),
  );
}
