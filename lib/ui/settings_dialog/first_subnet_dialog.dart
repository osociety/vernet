import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/base_settings_dialog.dart';
import 'package:vernet/utils/localization.dart';

class FirstSubnetDialog extends StatefulWidget {
  const FirstSubnetDialog({super.key});

  @override
  _FirstSubnetDialogState createState() => _FirstSubnetDialogState();
}

class _FirstSubnetDialogState extends BaseSettingsDialog<FirstSubnetDialog> {
  @override
  String getDialogTitle() {
    return context.l10n.firstSubnet;
  }

  @override
  String getHintText() {
    return context.l10n.firstSubnetDesc;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    final int val = int.parse(value);
    if (val != appSettings.firstSubnet) {
      appSettings.setFirstSubnet(val);
    }
  }

  @override
  String? validate(String? value) {
    if (value == null) return context.l10n.settingsValueRequired;
    try {
      final int val = int.parse(value);
      if (val < 1) {
        return context.l10n.settingsValueNaturalNumber;
      }
      if (val > appSettings.lastSubnet) {
        return context.l10n.settingsBeforeEnd;
      }
    } catch (e) {
      return context.l10n.settingsMustBeNumber;
    }
    return null;
  }

  @override
  String getInitialValue() {
    return appSettings.firstSubnet.toString();
  }
}
