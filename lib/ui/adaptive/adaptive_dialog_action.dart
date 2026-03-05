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
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
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
