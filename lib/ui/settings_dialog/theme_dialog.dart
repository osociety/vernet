import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';
import 'package:vernet/values/keys.dart';

class ThemeDialog extends StatefulWidget {
  const ThemeDialog({super.key});

  @override
  State<ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<ThemeDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return AdaptiveDialog(
      title: const Text("Choose theme"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AdaptiveListTile(
            title: const Text('Follow system'),
            leading: AdaptiveRadioButton<ThemePreference>(
              key: WidgetKey.systemThemeRadioButton.key,
              value: ThemePreference.system,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.system;
              },
            ),
          ),
          AdaptiveListTile(
            title: const Text('Dark'),
            leading: AdaptiveRadioButton<ThemePreference>(
              key: WidgetKey.darkThemeRadioButton.key,
              value: ThemePreference.dark,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.dark;
              },
            ),
          ),
          AdaptiveListTile(
            title: const Text('Light'),
            leading: AdaptiveRadioButton<ThemePreference>(
              key: WidgetKey.lightThemeRadioButton.key,
              value: ThemePreference.light,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.light;
              },
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }
}
