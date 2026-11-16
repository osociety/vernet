import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/base_settings_dialog.dart';
import 'package:vernet/utils/localization.dart';

class CustomSubnetDialog extends StatefulWidget {
  const CustomSubnetDialog({super.key});

  @override
  State<CustomSubnetDialog> createState() => _CustomSubnetDialogState();
}

class _CustomSubnetDialogState extends BaseSettingsDialog<CustomSubnetDialog> {
  @override
  String getDialogTitle() {
    return context.l10n.customSubnet;
  }

  @override
  String getHintText() {
    return context.l10n.customSubnetHint;
  }

  @override
  String getInitialValue() {
    return appSettings.customSubnet;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    if (value != appSettings.customSubnet) {
      appSettings.setCustomSubnet(value);
    }
  }

  @override
  String? validate(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) {
      return null;
    }
    final parts = input.split('.');
    if (parts.length != 4 ||
        parts.any((part) => part.isEmpty || int.tryParse(part) == null)) {
      return context.l10n.customSubnetInvalid;
    }
    final octets = parts.map(int.parse).toList();
    if (octets.any((octet) => octet < 0 || octet > 255)) {
      return context.l10n.customSubnetInvalid;
    }
    if (octets[3] == 0 || octets[3] == 255) {
      return context.l10n.customSubnetNotUsableHost;
    }
    return null;
  }
}
