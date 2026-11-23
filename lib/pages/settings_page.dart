import 'package:flutter/material.dart';
import 'package:vernet/pages/settings_category_page.dart';
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
          icon: Icons.palette_outlined,
          key: WidgetKey.settingsGeneralCategory,
          category: SettingsCategory.general,
        ),
        _categoryTile(
          context,
          title: l10n.settingsNetwork,
          icon: Icons.router_outlined,
          key: WidgetKey.settingsNetworkCategory,
          category: SettingsCategory.network,
        ),
        _categoryTile(
          context,
          title: l10n.settingsFeatures,
          icon: Icons.cloud_outlined,
          key: WidgetKey.settingsOnlineFeaturesCategory,
          category: SettingsCategory.features,
        ),
        _categoryTile(
          context,
          title: l10n.settingsAdvanced,
          icon: Icons.build_outlined,
          key: WidgetKey.settingsAdvancedCategory,
          category: SettingsCategory.advanced,
        ),
      ],
    );
  }

  Widget _categoryTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required WidgetKey key,
    required SettingsCategory category,
  }) {
    return Card(
      child: ListTile(
        key: key.key,
        leading: Icon(icon),
        title: Text(title),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => setState(() => _selectedCategory = category),
      ),
    );
  }
}
