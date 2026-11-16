import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/ui/external_link_dialog.dart';
import 'package:vernet/utils/app_strings.dart';

Future<void> launchURL(String url) async {
  if (await canLaunchUrlString(url)) {
    await launchUrlString(url);
  } else {
    throw appStrings().commonCouldNotLaunch(url);
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
String formatTimestamp(AppLocalizations l10n, DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inSeconds < 60) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo('${diff.inMinutes}');
  if (diff.inHours < 24) return l10n.timeHoursAgo('${diff.inHours}');
  return DateFormat.MMMd(l10n.localeName).add_jm().format(timestamp);
}
