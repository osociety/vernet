import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openWifiSettings(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Android: Use android_intent_plus to open WiFi settings
        const intent = AndroidIntent(
          action: 'android.settings.WIFI_SETTINGS',
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        // iOS: Show message (App Store restrictions prevent direct settings access)
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please go to Settings > Wi-Fi to connect'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (Platform.isMacOS) {
        // macOS: Open Network preferences
        await launchUrl(
          Uri.parse('x-apple.systempreferences:com.apple.preference.network'),
          mode: LaunchMode.externalApplication,
        );
      } else if (Platform.isWindows) {
        // Windows: Open WiFi network settings
        await launchUrl(
          Uri.parse('ms-settings:network-wifi'),
          mode: LaunchMode.externalApplication,
        );
      } else if (Platform.isLinux) {
        // Linux: Try GNOME network settings
        await launchUrl(
          Uri.parse('gnome-control-center wifi'),
        );
      } else {
        // Unknown platform
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please open WiFi settings manually'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // If opening settings fails, show a message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open WiFi settings manually'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
                    await _openWifiSettings(context);
                    // Don't set dismissed flag - prompt should show again
                    // if user returns without WiFi connected
                    if (context.mounted) {
                      Navigator.of(context).pop();
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
                  onPressed: () {
                    // Don't persist dismissal - prompt should show again if no WiFi
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
}
