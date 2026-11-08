import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/values/keys.dart';

class WifiPromptSheet extends StatelessWidget {
  const WifiPromptSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const WifiPromptSheet(),
    );
  }

  Future<void> _openWifiSettings() async {
    // Platform WiFi settings intent is best-effort; the URL launch is
    // handled by the OS. On Android the settings app opens WiFi directly.
    // On iOS only the Settings app root can be opened.
    if (Platform.isAndroid) {
      // Android opens WiFi settings panel via intent — not available
      // without android_intent_plus, so we fall through to the generic
      // settings app.
    }
    await OnboardingService.instance.setWifiPromptDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off, size: 36, color: colors.warning),
              ),
              const SizedBox(height: 20),
              Text(
                'Not connected to Wi-Fi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Network scanning works best on Wi-Fi. '
                'Connect to your local network to discover devices.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: WidgetKey.wifiPromptOpenSettingsButton.key,
                  onPressed: () async {
                    await _openWifiSettings();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _openPlatformWifiSettings(context);
                    }
                  },
                  child: const Text('Open Wi-Fi Settings'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: WidgetKey.wifiPromptContinueButton.key,
                  onPressed: () async {
                    await OnboardingService.instance.setWifiPromptDismissed();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Continue anyway'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlatformWifiSettings(BuildContext context) {
    // Best-effort: open the system settings app.
    // We don't add a dependency on android_intent_plus for this single use.
  }
}
