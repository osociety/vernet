import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/changelog_data.dart';
import 'package:vernet/values/keys.dart';

class WhatsNewDialog extends StatefulWidget {
  const WhatsNewDialog({super.key, this.entry, this.releaseUrl});

  final ChangelogEntry? entry;

  /// The running build's GitHub release page, from [githubReleaseUrl]. Null
  /// when the version or build number could not be read, which removes the
  /// link rather than pointing it at a 404.
  final String? releaseUrl;

  static Future<void> showIfNewVersion(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final service = OnboardingService.instance;
    final hasSeen = await service.hasSeenWhatsNew(info.version);

    // Already seen What's New for this version
    if (hasSeen) return;
    if (!context.mounted) return;

    final entry = changelogEntryForVersion(info.version, context.l10n);

    // Nothing to announce: leave the version unmarked so the dialog can still
    // appear once notes are added, instead of showing an empty one forever.
    if (entry == null) return;

    await showAdaptiveDialog(
      context: context,
      builder: (_) => WhatsNewDialog(
        entry: entry,
        releaseUrl: githubReleaseUrl(info.version, info.buildNumber),
      ),
    );
    // Mark as seen after user closes the dialog
    await service.markWhatsNewSeen(info.version);
  }

  static Future<void> showCurrent(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final entry = changelogEntryForVersion(info.version, context.l10n);

    await showAdaptiveDialog(
      context: context,
      builder: (_) => WhatsNewDialog(
        entry: entry,
        releaseUrl: githubReleaseUrl(info.version, info.buildNumber),
      ),
    );
  }

  @override
  State<WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<WhatsNewDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;

    return FadeTransition(
      opacity: _controller,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: colors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.whatsNewDialogTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v${entry.version}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(entry.changes.length, (i) {
                  return _AnimatedBullet(
                    text: entry.changes[i],
                    delay: Duration(milliseconds: 100 * (i + 1)),
                  );
                }),
              ] else
                Text(context.l10n.whatsNewEmpty),
              if (widget.releaseUrl != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: WidgetKey.whatsNewReleaseLink.key,
                    onPressed: () => launchURLWithWarning(
                      context,
                      widget.releaseUrl!,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(context.l10n.whatsNewReleaseLink),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: WidgetKey.whatsNewGotItButton.key,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonGotIt),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBullet extends StatelessWidget {
  const _AnimatedBullet({
    required this.text,
    required this.delay,
  });

  /// Material 3's `bodyMedium` line-height ratio, which is what the dialog's
  /// text is styled with; only a theme that drops the ratio needs this.
  static const double _bodyMediumLineHeight = 1.43;

  final String text;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    // The tick has to meet the note's first line, and a fixed top offset only
    // ever matched one language: the same string is two lines in German and one
    // in English, and a large font scale moves the line either way. Boxing the
    // icon at the line height of the style `AlertDialog` actually hands the text
    // — `bodyMedium`, per Flutter's dialog source — centres it on that line
    // whatever the locale, the scale, or how deep the note wraps.
    final style = Theme.of(context).textTheme.bodyMedium;
    final lineHeight = MediaQuery.textScalerOf(context).scale(
      (style?.height ?? _bodyMediumLineHeight) * (style?.fontSize ?? 14),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay.inMilliseconds),
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: lineHeight,
              // `widthFactor` keeps the box as wide as the tick: an `Align` with
              // no factor takes the row's whole remaining width, which would
              // starve the note beside it.
              child: Align(
                widthFactor: 1,
                child: Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
