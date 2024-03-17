import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';

class ExternalLinkWarningDialog extends StatefulWidget {
  const ExternalLinkWarningDialog({super.key, required this.link});

  final String link;

  @override
  State<ExternalLinkWarningDialog> createState() =>
      _ExternalLinkWarningDialogState();
}

class _ExternalLinkWarningDialogState extends State<ExternalLinkWarningDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm external link opening"),
      content: Text(widget.link),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: () {
            launchURL(widget.link);
          },
          icon: const Icon(Icons.link),
          label: const Text('Open Link'),
        ),
      ],
    );
  }
}
