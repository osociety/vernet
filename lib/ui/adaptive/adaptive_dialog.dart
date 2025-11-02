import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    this.title,
    this.content,
    required this.actions,
    this.onClose,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Platform.isIOS || Platform.isMacOS
        ? CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              primaryColor:
                  themeChange.darkTheme ? Colors.white54 : Colors.black54,
            ),
            child: CupertinoAlertDialog(
              title: title,
              content: content,
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: onClose ??
                      () {
                        Navigator.pop(context);
                      },
                  child: const Text(
                    "Close",
                  ),
                ),
                ...actions,
              ],
            ),
          )
        : AlertDialog(
            title: title,
            content: content,
            actions: [
              TextButton(
                onPressed: onClose ??
                    () {
                      Navigator.pop(context);
                    },
                child: const Text("Close"),
              ),
              ...actions,
            ],
          );
  }
}
