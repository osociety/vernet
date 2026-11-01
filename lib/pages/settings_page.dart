import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/main.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.changeThemeTile.key,
              title: const Text('Theme'),
              subtitle: Text(themeChange.themePref.name),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const ThemeDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              title: const Text('Allow internet access in the app'),
              trailing: Switch(
                key: WidgetKey.inAppInternetSwitch.key,
                value: appSettings.inAppInternet,
                onChanged: (bool? value) async {
                  appSettings.setInAppInternet(value ?? false);
                  await appSettings.load();
                  setState(() {});
                },
              ),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              title: const Text('Find devices when the app opens'),
              trailing: Switch(
                key: WidgetKey.runOnAppStartupSwitch.key,
                value: appSettings.runScanOnStartup,
                onChanged: (bool? value) async {
                  appSettings.setRunScanOnStartup(value ?? false);
                  await appSettings.load();
                  setState(() {});
                },
              ),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.firstSubnetTile.key,
              title: const Text(StringValue.firstSubnet),
              subtitle: const Text(StringValue.firstSubnetDesc),
              trailing: Text(
                '${appSettings.firstSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const FirstSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.lastSubnetTile.key,
              title: const Text(StringValue.lastSubnet),
              subtitle: const Text(StringValue.lastSubnetDesc),
              trailing: Text(
                '${appSettings.lastSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const LastSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.socketTimeoutTile.key,
              title: const Text(StringValue.socketTimeout),
              subtitle: const Text(StringValue.socketTimeoutdesc),
              trailing: Text(
                '${appSettings.socketTimeout} ms',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const SocketTimeoutDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.pingCountTile.key,
              title: const Text(StringValue.pingCount),
              subtitle: const Text(StringValue.pingCountDesc),
              trailing: Text(
                '${appSettings.pingCount}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const PingCountDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.customSubnetTile.key,
              title: const Text(StringValue.customSubnet),
              subtitle: const Text(StringValue.customSubnetDesc),
              trailing: Text(
                appSettings.customSubnet,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showAdaptiveDialog(
                  context: context,
                  builder: (context) => const CustomSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              title: const Text('Check for a newer version'),
              trailing: IconButton(
                key: WidgetKey.checkForUpdatesButton.key,
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  checkForUpdates(context, showIfNoUpdate: true);
                },
              ),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              title: const Text('Rate Vernet'),
              onTap: () {
                if (Platform.isLinux ||
                    Platform.isMacOS ||
                    Platform.isWindows) {
                  launchURLWithWarning(context, _srcUrl);
                } else if (Platform.isAndroid) {
                  navigateToStore(context);
                }
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              title: const Text('About'),
              onTap: () async {
                final info = await PackageInfo.fromPlatform();
                showAboutDialog(
                  context: context,
                  applicationName: 'Vernet',
                  applicationVersion: '${info.version}+${info.buildNumber}',
                  applicationIcon: ClipOval(
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  children: [
                    AdaptiveListTile(
                      leading: const Icon(Icons.speed),
                      title: const Text('Speed Test Attribution'),
                      subtitle: const Text('Powered by M-Lab NDT7'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showMlabInfo(context);
                      },
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('Tell us about a problem'),
                      onTap: () {
                        launchURLWithWarning(context, _issueUrl);
                      },
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.favorite),
                      title: const Text('Donate'),
                      onTap: () {
                        launchURLWithWarning(context, _donateUrl);
                      },
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('View the project'),
                      onTap: () {
                        launchURLWithWarning(context, _srcUrl);
                      },
                    ),
                    const AdaptiveListTile(
                      title: Text(
                        'Made with ❤️ in India',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const String _srcUrl = 'https://github.com/osociety/vernet';
  final String _issueUrl = '$_srcUrl/issues';
  final String _donateUrl = '$_srcUrl#support-and-donate';

  void _showMlabInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Measurement Lab (M-Lab)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Vernet uses M-Lab's NDT7 protocol for internet speed testing. M-Lab is a research initiative providing open internet measurement data.",
              ),
              const SizedBox(height: 16),
              Text(
                'Important Links',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildMlabLink(
                context,
                icon: Icons.language,
                title: 'M-Lab Website',
                url: 'https://www.measurementlab.net/',
              ),
              _buildMlabLink(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                url: 'https://www.measurementlab.net/privacy-policy/',
              ),
              _buildMlabLink(
                context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                url: 'https://www.measurementlab.net/terms-of-service/',
              ),
              _buildMlabLink(
                context,
                icon: Icons.info_outline,
                title: 'About NDT Test',
                url: 'https://www.measurementlab.net/tests/ndt/',
              ),
              const SizedBox(height: 16),
              Text(
                'Data Collection',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'M-Lab collects network performance data for research purposes. This includes your IP address, test results, and network characteristics. All data is made publicly available to support internet research.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMlabLink(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => launchURLWithWarning(context, url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
