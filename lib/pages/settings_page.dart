import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/settings_category_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _selectedCategory;
    if (selectedCategory != null) {
      return SettingsCategoryPage(
        category: selectedCategory,
        onBack: () => setState(() => _selectedCategory = null),
      );
    }

    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _categoryTile(
          context,
          title: l10n.settingsGeneral,
          subtitle: l10n.settingsGeneralDesc,
          icon: Icons.palette_outlined,
          key: WidgetKey.settingsGeneralCategory,
          category: SettingsCategory.general,
        ),
        _categoryTile(
          context,
          title: l10n.settingsNetwork,
          subtitle: l10n.settingsNetworkDesc,
          icon: Icons.router_outlined,
          key: WidgetKey.settingsNetworkCategory,
          category: SettingsCategory.network,
        ),
        _categoryTile(
          context,
          title: l10n.settingsFeatures,
          subtitle: l10n.settingsFeaturesDesc,
          icon: Icons.cloud_outlined,
          key: WidgetKey.settingsOnlineFeaturesCategory,
          category: SettingsCategory.features,
        ),
        _categoryTile(
          context,
          title: l10n.settingsAdvanced,
          subtitle: l10n.settingsAdvancedDesc,
          icon: Icons.build_outlined,
          key: WidgetKey.settingsAdvancedCategory,
          category: SettingsCategory.advanced,
        ),
        Card(
          child: ListTile(
            key: WidgetKey.resetAllSettingsButton.key,
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.resetAllSettings),
            subtitle: Text(l10n.resetAllSettingsDesc),
            onTap: _confirmResetAll,
          ),
        ),
      ],
    );
  }

  /// Resets every setting the settings pages expose. Consent and onboarding
  /// state are deliberately left alone, so a reset never walks the user back
  /// through first-run screens.
  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.resetAllSettingsConfirmTitle),
        content: Text(context.l10n.resetAllSettingsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.resetAllSettings),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await AppSettings.instance.resetAllSettings();
    if (!mounted) return;
    Provider.of<DarkThemeProvider>(context, listen: false).themePref =
        ThemePreference.system;
    Provider.of<LocaleProvider>(context, listen: false).locale = null;
    setState(() {});
  }

  /// Opens a category inline on wide windows, where the settings page is its own
  /// pane under the sidebar. A compact window already carries the shell's AppBar,
  /// so the category is pushed instead: two stacked headings were the result of
  /// drawing this page's header under it.
  void _openCategory(SettingsCategory category) {
    final isCompact =
        MediaQuery.sizeOf(context).width <= TabBarPage.largeLayoutBreakpoint;
    if (isCompact) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsCategoryPage(category: category),
        ),
      );
      return;
    }
    setState(() => _selectedCategory = category);
  }

  Widget _categoryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required WidgetKey key,
    required SettingsCategory category,
  }) {
    return Card(
      child: ListTile(
        key: key.key,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => _openCategory(category),
      ),
    );
  }
}
