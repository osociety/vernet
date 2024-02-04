import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/models/dark_theme_provider.dart';

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
    return AlertDialog(
      title: const Text("Choose theme"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: const Text('Follow system'),
            leading: Radio<ThemePreference>(
              value: ThemePreference.system,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.system;
              },
            ),
          ),
          ListTile(
            title: const Text('Dark'),
            leading: Radio<ThemePreference>(
              value: ThemePreference.dark,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.dark;
              },
            ),
          ),
          ListTile(
            title: const Text('Light'),
            leading: Radio<ThemePreference>(
              value: ThemePreference.light,
              groupValue: themeChange.themePref,
              onChanged: (value) {
                themeChange.themePref = ThemePreference.light;
              },
            ),
          ),
        ],
      ),
    );
  }
}
