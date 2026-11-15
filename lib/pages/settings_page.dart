import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/donate_page.dart';
import 'package:vernet/pages/onboarding/whats_new_page.dart';
import 'package:vernet/pages/updates_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/store/store_features.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final localeChange = Provider.of<LocaleProvider>(context);
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: ListTile(
              key: WidgetKey.changeThemeTile.key,
              title: const Text('Theme'),
              subtitle: Text(themeChange.themePref.name),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const ThemeDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              key: WidgetKey.languageTile.key,
              title: Text(l10n.languageTitle),
              subtitle: Text(l10n.languageDesc),
              trailing: DropdownButton<Locale?>(
                value: localeChange.locale,
                underline: const SizedBox.shrink(),
                items: [
                  // No value means follow the system language.
                  DropdownMenuItem(child: Text(l10n.languageSystemDefault)),
                  ...AppLocalizations.supportedLocales.map(
                    (locale) => DropdownMenuItem(
                      value: locale,
                      child: Text(languageName(locale)),
                    ),
                  ),
                ],
                onChanged: (locale) => localeChange.locale = locale,
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('In-App Internet'),
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
            child: ListTile(
              key: WidgetKey.firstSubnetTile.key,
              title: Text(l10n.firstSubnet),
              subtitle: Text(l10n.firstSubnetDesc),
              trailing: Text(
                '${appSettings.firstSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const FirstSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              key: WidgetKey.lastSubnetTile.key,
              title: Text(l10n.lastSubnet),
              subtitle: Text(l10n.lastSubnetDesc),
              trailing: Text(
                '${appSettings.lastSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const LastSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              key: WidgetKey.socketTimeoutTile.key,
              title: Text(l10n.socketTimeout),
              subtitle: Text(l10n.socketTimeoutDesc),
              trailing: Text(
                '${appSettings.socketTimeout} ms',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const SocketTimeoutDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              key: WidgetKey.pingCountTile.key,
              title: Text(l10n.pingCount),
              subtitle: Text(l10n.pingCountDesc),
              trailing: Text(
                '${appSettings.pingCount}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const PingCountDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              key: WidgetKey.customSubnetTile.key,
              title: Text(l10n.customSubnet),
              subtitle: Text(l10n.customSubnetDesc),
              trailing: Text(
                appSettings.customSubnet,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
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
              key: WidgetKey.whatsNewSettingsTile.key,
              title: const Text("What's new"),
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () => WhatsNewDialog.showCurrent(context),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              key: WidgetKey.donateSettingsTile.key,
              title: const Text('Support Vernet'),
              subtitle: const Text('Donations, stars and ratings'),
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const DonatePage(),
                  ),
                );
              },
            ),
          ),
          if (kUpdateChecksEnabled)
            Card(
              child: AdaptiveListTile(
                key: WidgetKey.updateSettingsTile.key,
                title: const Text('Updates & beta'),
                subtitle: const Text('Channel, automatic updates, pre-release '
                    'builds'),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const UpdatesPage(),
                    ),
                  );
                },
              ),
            ),
          if (kStoreBuild)
            Card(
              child: AdaptiveListTile(
                key: WidgetKey.rateAppTile.key,
                title: const Text('Rate Vernet'),
                subtitle: const Text('Opens Google Play'),
                trailing: Icon(
                  Icons.star_border,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: openStoreListing,
              ),
            ),
          Card(
            child: ListTile(
              title: const Text('About'),
              onTap: () async {
                final info = await PackageInfo.fromPlatform();
                if (!context.mounted) return;
                showAboutDialog(
                  context: context,
                  applicationName: 'Vernet',
                  applicationVersion: '${info.version}+${info.buildNumber}',
                  applicationIcon: const Icon(Icons.radar),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('Report Issues'),
                      onTap: () {
                        launchURLWithWarning(context, _issueUrl);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite),
                      title: const Text('Donate'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const DonatePage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Source Code'),
                      onTap: () {
                        launchURLWithWarning(context, _srcUrl);
                      },
                    ),
                    const ListTile(
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

  static const String _srcUrl = 'https://github.com/git-elliot/vernet';
  final String _issueUrl = '$_srcUrl/issues';
}
