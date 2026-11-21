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
import 'package:vernet/utils/app_strings.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/store_links.dart';

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
              title: Text(l10n.themeTitle),
              subtitle: Text(switch (themeChange.themePref) {
                ThemePreference.system => l10n.themeSystem,
                ThemePreference.dark => l10n.themeDark,
                ThemePreference.light => l10n.themeLight,
              }),
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
            child: Column(
              children: [
                ListTile(
                  key: WidgetKey.languageTile.key,
                  title: Text(l10n.languageTitle),
                  subtitle: Text(l10n.languageDesc),
                ),
                Padding(
                  // The chooser stays inline on this page, but below the row
                  // text: as an unsized `trailing` its intrinsic width — the
                  // longest language name plus the arrow — filled a phone-width
                  // tile and tripped ListTile's trailing assertion (#675).
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: DropdownButton<Locale?>(
                      value: localeChange.locale,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        // No value means follow the system language.
                        DropdownMenuItem(
                          child: Text(
                            l10n.languageSystemDefault(
                              languageName(systemDefaultLocale()),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...AppLocalizations.supportedLocales.map(
                          (locale) => DropdownMenuItem(
                            value: locale,
                            child: Text(
                              languageName(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (locale) => localeChange.locale = locale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.inAppInternetTitle),
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
              title: Text(l10n.whatsNewTitle),
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
              title: Text(l10n.navSupport),
              subtitle: Text(l10n.supportVernetDesc),
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
                title: Text(l10n.updatesTitle),
                subtitle: Text(l10n.updatesDesc),
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
                title: Text(l10n.rateAppTitle),
                subtitle: Text(l10n.rateAppDesc),
                trailing: Icon(
                  Icons.star_border,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: openStoreListing,
              ),
            ),
          Card(
            child: ListTile(
              title: Text(l10n.aboutTitle),
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
                      title: Text(l10n.reportIssuesTitle),
                      onTap: () {
                        launchURLWithWarning(context, githubIssuesUrl);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite),
                      title: Text(l10n.donateTitle),
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
                      title: Text(l10n.sourceCodeTitle),
                      onTap: () {
                        launchURLWithWarning(context, githubRepositoryUrl);
                      },
                    ),
                    ListTile(
                      title: Text(
                        l10n.madeInIndia,
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
}
