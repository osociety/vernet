import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/base_settings_dialog.dart';
import 'package:vernet/utils/localization.dart';

class LastSubnetDialog extends StatefulWidget {
  const LastSubnetDialog({super.key});

  @override
  _LastSubnetDialogState createState() => _LastSubnetDialogState();
}

class _LastSubnetDialogState extends BaseSettingsDialog<LastSubnetDialog> {
  @override
  String getDialogTitle() {
    return context.l10n.lastSubnet;
  }

  @override
  String getHintText() {
    return context.l10n.lastSubnetDesc;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    final int val = int.parse(value);
    if (val != appSettings.lastSubnet) {
      appSettings.setLastSubnet(val);
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
      if (val < appSettings.firstSubnet) {
        return context.l10n.settingsAfterStart;
      }
    } catch (e) {
      return context.l10n.settingsMustBeNumber;
    }
    return null;
  }

  @override
  String getInitialValue() {
    return appSettings.lastSubnet.toString();
  }
}
