import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _openWifiSettings(BuildContext context) async {
    // Open system settings app where user can enable/connect to WiFi
    await openAppSettings();
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
}
