import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';
import 'package:vernet/utils/localization.dart';

class ExternalLinkWarningDialog<T extends Dialog> extends StatelessWidget {
  const ExternalLinkWarningDialog({super.key, required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdaptiveDialog(
      title: Text(l10n.externalLinkTitle),
      content: Text(link),
      actions: [
        AdaptiveDialogAction(
          isDestructiveAction: true,
          child: Text(l10n.externalLinkOpen),
          onPressed: () {
            launchURL(link);
          },
        ),
      ],
    );
  }
}
