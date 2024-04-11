import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/models/dark_theme_provider.dart';

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.minVerticalPadding,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense,
    this.onLongPress,
    this.contentPadding,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? subtitle;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final double? minVerticalPadding;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;

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
            child: Padding(
              padding: contentPadding ?? const EdgeInsets.all(10),
              child: CupertinoListTile(
                leading: leading,
                title: title,
                subtitle: subtitle,
                trailing: trailing,
                onTap: onTap,
                padding: EdgeInsets.symmetric(
                  vertical: minVerticalPadding ?? (dense ?? false ? 10 : 5),
                ),
              ),
            ),
          )
        : ListTile(
            minVerticalPadding: minVerticalPadding,
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onTap: onTap,
            dense: dense,
            onLongPress: onLongPress,
            contentPadding: contentPadding,
          );
  }
}
