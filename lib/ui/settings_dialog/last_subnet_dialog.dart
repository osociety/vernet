import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/strings.dart';

import '../../ui/base_settings_dialog.dart';

class LastSubnetDialog extends StatefulWidget {
  const LastSubnetDialog({Key? key}) : super(key: key);

  @override
  _LastSubnetDialogState createState() => _LastSubnetDialogState();
}

class _LastSubnetDialogState extends BaseSettingsDialog<LastSubnetDialog> {
  @override
  String getDialogTitle() {
    return StringValue.LAST_SUBNET;
  }

  @override
  String getHintText() {
    return StringValue.LAST_SUBNET_DESC;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    int val = int.parse(value);
    if (val != appSettings.lastSubnet) {
      print('saving value');
      appSettings.setLastSubnet(val);
    }
  }

  @override
  String? validate(String? value) {
    if (value == null) return 'Value required';
    try {
      int val = int.parse(value);
      if (val < 1) {
        return 'Value must be a natural number';
      }
      if (val < appSettings.firstSubnet) {
        return 'Value must be greater than first subnet';
      }
    } catch (e) {
      return 'Must be a number';
    }
  }

  @override
  String getInitialValue() {
    return appSettings.lastSubnet.toString();
  }
}
