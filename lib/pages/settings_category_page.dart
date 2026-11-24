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
import 'package:vernet/ui/app_mark.dart';
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

enum SettingsCategory { general, network, features, advanced }

class SettingsCategoryPage extends StatefulWidget {
  const SettingsCategoryPage({
    required this.category,
    required this.onBack,
    super.key,
  });

  final SettingsCategory category;
  final VoidCallback onBack;

  @override
  State<SettingsCategoryPage> createState() => _SettingsCategoryPageState();
}

class _SettingsCategoryPageState extends State<SettingsCategoryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (widget.category) {
      SettingsCategory.general => l10n.settingsGeneral,
      SettingsCategory.network => l10n.settingsNetwork,
      SettingsCategory.features => l10n.settingsFeatures,
      SettingsCategory.advanced => l10n.settingsAdvanced,
    };

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      key: WidgetKey.settingsCategoryBackButton.key,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: switch (widget.category) {
                    SettingsCategory.general => _generalSettings(context),
                    SettingsCategory.network => _networkSettings(context),
                    SettingsCategory.features => _featureSettings(context),
                    SettingsCategory.advanced => _advancedSettings(context),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _generalSettings(BuildContext context) {
    final l10n = context.l10n;
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final localeChange = Provider.of<LocaleProvider>(context);
    return [
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
              // Keep the language control below the row text so its intrinsic
              // width cannot overflow narrow settings pages.
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: DropdownButton<Locale?>(
                  value: localeChange.locale,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
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
          title: Text(l10n.aboutTitle),
          onTap: () => _showAbout(context),
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
      _supportTile(context),
      if (kUpdateChecksEnabled) _updatesTile(context),
      if (kStoreBuild) _rateTile(context),
    ];
  }

  List<Widget> _networkSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      Card(
        child: ListTile(
          key: WidgetKey.firstSubnetTile.key,
          title: Text(l10n.firstSubnet),
          subtitle: Text(l10n.firstSubnetDesc),
          trailing: _settingValue(context, '${appSettings.firstSubnet}'),
          onTap: () => _showSettingDialog(context, const FirstSubnetDialog()),
        ),
      ),
      Card(
        child: ListTile(
          key: WidgetKey.lastSubnetTile.key,
          title: Text(l10n.lastSubnet),
          subtitle: Text(l10n.lastSubnetDesc),
          trailing: _settingValue(context, '${appSettings.lastSubnet}'),
          onTap: () => _showSettingDialog(context, const LastSubnetDialog()),
        ),
      ),
      Card(
        child: ListTile(
          key: WidgetKey.socketTimeoutTile.key,
          title: Text(l10n.socketTimeout),
          subtitle: Text(l10n.socketTimeoutDesc),
          trailing: _settingValue(context, '${appSettings.socketTimeout} ms'),
          onTap: () => _showSettingDialog(context, const SocketTimeoutDialog()),
        ),
      ),
    ];
  }

  List<Widget> _featureSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      Card(
        child: ListTile(
          title: Text(l10n.inAppInternetTitle),
          trailing: Switch(
            key: WidgetKey.inAppInternetSwitch.key,
            value: appSettings.inAppInternet,
            onChanged: (value) async {
              await appSettings.setInAppInternet(value);
              if (mounted) setState(() {});
            },
          ),
        ),
      ),
    ];
  }

  Widget _supportTile(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: AdaptiveListTile(
        key: WidgetKey.donateSettingsTile.key,
        title: Text(l10n.navSupport),
        subtitle: Text(l10n.supportVernetDesc),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const DonatePage()),
        ),
      ),
    );
  }

  Widget _updatesTile(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: AdaptiveListTile(
        key: WidgetKey.updateSettingsTile.key,
        title: Text(l10n.updatesTitle),
        subtitle: Text(l10n.updatesDesc),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const UpdatesPage()),
        ),
      ),
    );
  }

  Widget _rateTile(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: AdaptiveListTile(
        key: WidgetKey.rateAppTile.key,
        title: Text(l10n.rateAppTitle),
        subtitle: Text(l10n.rateAppDesc),
        trailing: Icon(
          Icons.star_border,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: openStoreListing,
      ),
    );
  }

  List<Widget> _advancedSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      Card(
        child: ListTile(
          key: WidgetKey.pingCountTile.key,
          title: Text(l10n.pingCount),
          subtitle: Text(l10n.pingCountDesc),
          trailing: _settingValue(context, '${appSettings.pingCount}'),
          onTap: () => _showSettingDialog(context, const PingCountDialog()),
        ),
      ),
      Card(
        child: ListTile(
          key: WidgetKey.customSubnetTile.key,
          title: Text(l10n.customSubnet),
          subtitle: Text(l10n.customSubnetDesc),
          trailing: _settingValue(context, appSettings.customSubnet),
          onTap: () => _showSettingDialog(context, const CustomSubnetDialog()),
        ),
      ),
    ];
  }

  Widget _settingValue(BuildContext context, String value) {
    return Text(
      value,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.secondary),
    );
  }

  Future<void> _showSettingDialog(BuildContext context, Widget dialog) async {
    await showDialog(context: context, builder: (_) => dialog);
    await appSettings.load();
    if (mounted) setState(() {});
  }

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final l10n = context.l10n;
    showAboutDialog(
      context: context,
      applicationName: 'Vernet',
      applicationVersion: '${info.version}+${info.buildNumber}',
      applicationIcon: const AppMark(),
      children: [
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: Text(l10n.reportIssuesTitle),
          onTap: () => launchURLWithWarning(context, githubIssuesUrl),
        ),
        ListTile(
          leading: const Icon(Icons.favorite),
          title: Text(l10n.donateTitle),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DonatePage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(l10n.sourceCodeTitle),
          onTap: () => launchURLWithWarning(context, githubRepositoryUrl),
        ),
        ListTile(
          title: Text(l10n.madeInIndia, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
