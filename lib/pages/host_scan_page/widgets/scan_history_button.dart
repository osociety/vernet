import 'package:flutter/material.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

/// Opens the stored scan reports.
///
/// Desktop puts it in the page `AppBar`; on a phone the shell owns that bar and
/// has no action slot for the page, so the scan results header carries it.
class ScanHistoryButton extends StatelessWidget {
  const ScanHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: WidgetKey.scanHistoryIconButton.key,
      tooltip: context.l10n.previousScansTitle,
      icon: const Icon(Icons.history),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const ScanHistoryPage(),
          ),
        );
      },
    );
  }
}
