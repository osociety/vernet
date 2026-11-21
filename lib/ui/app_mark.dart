import 'package:flutter/material.dart';

/// The Vernet logo drawn in a single colour that follows the active theme.
///
/// `assets/app_icon.png` is the mark in white on a purple gradient with no
/// transparent pixels, so tinting it would paint a solid square. The splash
/// asset is the same mark as white on transparency, and its arcs are drawn at a
/// lower alpha than the strokes — tinting it with `srcIn` keeps that difference
/// and turns the mark near-black in light mode, near-white in dark mode. It is
/// declared in `pubspec.yaml`, so every build flavor ships it, unlike the
/// per-flavor launcher icons.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 64});

  /// Side of the square canvas. The mark itself is letterboxed inside it, so it
  /// paints at roughly 56% of this width.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
      child: Image.asset(
        'assets/splash11/splash_dark/ic_launcher_round.png',
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        fit: BoxFit.contain,
      ),
    );
  }
}
