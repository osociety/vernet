import 'package:flutter/material.dart';

/// Tells the page inside the navigation shell whether the shell already paints
/// an `AppBar` for it.
///
/// The shell shows an `AppBar` only on compact widths, so a page that also
/// builds one stacks two headings on a phone while a desktop window, which has
/// no shell bar, needs the page's own bar as its only title. A page reads this
/// scope instead of measuring the window itself, because a page pushed over the
/// shell (device detail, scan report) is compact too and still has to own its
/// bar and back button — the absence of this scope is what says "I was pushed".
class ShellChrome extends InheritedWidget {
  const ShellChrome({
    super.key,
    required this.hasAppBar,
    required super.child,
  });

  /// Whether the surrounding shell is painting an `AppBar` above this page.
  final bool hasAppBar;

  /// Whether the shell's bar already carries this page's heading.
  ///
  /// False for a page built outside the shell, which keeps its own `AppBar`.
  static bool providesAppBar(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChrome>()?.hasAppBar ??
      false;

  @override
  bool updateShouldNotify(ShellChrome oldWidget) =>
      oldWidget.hasAppBar != hasAppBar;
}
