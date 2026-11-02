import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vernet/ui/external_link_dialog.dart';

Future<void> launchURL(String url) async {
  if (await canLaunchUrlString(url)) {
    await launchUrlString(url);
  } else {
    throw 'Could not launch $url';
  }
}

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

/// Formats a timestamp as relative age, falling back to an absolute
/// date-time once it is older than a day.
String formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('MMM d, h:mm a').format(timestamp);
}
