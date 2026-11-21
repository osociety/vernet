import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

/// `CupertinoListTile`'s own default for the square box around `leading`, which
/// is sized for an icon.
const double _kCupertinoLeadingSize = 28;

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
    this.platform,
    this.leadingSize,
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
  final String? platform;

  /// The side length of the square box the Cupertino branch fits [leading] into.
  ///
  /// `CupertinoListTile` always clamps its leading widget to a square, so a
  /// wide leading such as a four- or five-digit port number needs a box wide
  /// enough for it; `ListTile` sizes that slot from the widget itself and
  /// ignores this. Defaults to the 28 `CupertinoListTile` uses for an icon.
  final double? leadingSize;

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final String currentPlatform = platform ?? Platform.operatingSystem;
    return currentPlatform == 'ios' || currentPlatform == 'macos'
        ? _cupertinoTile(context, themeChange)
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

  /// [CupertinoListTile] has no long-press callback, so the row wraps it in a
  /// gesture detector. Without that wrapper a long press was handled on
  /// Android, Windows and Linux but silently ignored on iOS and macOS, where the
  /// device row's copy-address action lives.
  Widget _cupertinoTile(BuildContext context, DarkThemeProvider themeChange) {
    final tile = CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: themeChange.darkTheme ? Colors.white54 : Colors.black54,
      ),
      child: Padding(
        // 16 horizontal matches the content padding `ListTile` gives the other
        // rows on the same page, so a list mixing the two keeps one leading
        // edge. CupertinoListTile is handed vertical-only padding below.
        padding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: CupertinoListTile(
          leading: leading,
          leadingSize: leadingSize ?? _kCupertinoLeadingSize,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
          padding: EdgeInsets.symmetric(
            vertical: minVerticalPadding ?? (dense ?? false ? 10 : 5),
          ),
        ),
      ),
    );
    if (onLongPress == null) return tile;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );
  }
}
