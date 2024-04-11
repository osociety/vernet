import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveDialogAction extends StatelessWidget {
  const AdaptiveDialogAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });
  final Widget child;
  final VoidCallback onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS || Platform.isMacOS
        ? CupertinoDialogAction(
            onPressed: onPressed,
            isDefaultAction: isDefaultAction,
            isDestructiveAction: isDestructiveAction,
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            child: child,
          );
  }
}
