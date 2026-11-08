import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/values/changelog_data.dart';
import 'package:vernet/values/keys.dart';

class WhatsNewDialog extends StatefulWidget {
  const WhatsNewDialog({super.key, this.entry});

  final ChangelogEntry? entry;

  static Future<void> showIfNewVersion(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final service = OnboardingService.instance;
    final hasSeen = await service.hasSeenWhatsNew(info.version);

    // Already seen What's New for this version
    if (hasSeen) return;

    final entry = kChangelogEntries
        .cast<ChangelogEntry?>()
        .firstWhere((e) => e!.version == info.version, orElse: () => null);

    if (!context.mounted) return;
    await showAdaptiveDialog(
      context: context,
      builder: (_) => WhatsNewDialog(entry: entry),
    );
    // Mark as seen after user closes the dialog
    await service.markWhatsNewSeen(info.version);
  }

  static Future<void> showCurrent(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final entry = kChangelogEntries
        .cast<ChangelogEntry?>()
        .firstWhere((e) => e!.version == info.version, orElse: () => null);

    if (!context.mounted) return;
    await showAdaptiveDialog(
      context: context,
      builder: (_) => WhatsNewDialog(entry: entry),
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
            const Expanded(child: Text("What's New")),
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
                    controller: _controller,
                  );
                }),
              ] else
                const Text('No release notes available for this version.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: WidgetKey.whatsNewGotItButton.key,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
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
    required this.controller,
  });

  final String text;
  final Duration delay;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
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
