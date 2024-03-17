import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';

class ExternalLinkWarningDialog extends StatelessWidget {
  const ExternalLinkWarningDialog({super.key, required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm to open external link"),
      content: Text(link),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: () {
            launchURL(link);
          },
          icon: const Icon(Icons.link),
          label: const Text('Open Link'),
        ),
      ],
    );
  }
}
