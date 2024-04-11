import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';

class ExternalLinkWarningDialog<T extends Dialog> extends StatelessWidget {
  const ExternalLinkWarningDialog({super.key, required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: title,
      content: content,
      actions: actions(context),
    );
  }

  Widget get title => const Text("Confirm external link");
  Widget get content => Text(link);
  List<Widget> actions(BuildContext context) {
    return [
      AdaptiveDialogAction(
        isDestructiveAction: true,
        child: const Text('Open Link'),
        onPressed: () {
          launchURL(link);
        },
      ),
    ];
  }
}
