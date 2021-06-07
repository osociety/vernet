import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/strings.dart';

import '../../ui/base_settings_dialog.dart';

class MaxHostDialog extends StatefulWidget {
  const MaxHostDialog({Key? key}) : super(key: key);

  @override
  _MaxHostDialogState createState() => _MaxHostDialogState();
}

class _MaxHostDialogState extends BaseSettingsDialog<MaxHostDialog> {
  @override
  String getDialogTitle() {
    return StringValue.MAX_HOST_SIZE;
  }

  @override
  String getHintText() {
    return StringValue.MAX_HOST_SIZE_DESC;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    int val = int.parse(value);
    if (val != appSettings.maxNetworkSize) {
      print('saving value');
      appSettings.setMaxNetworkSize(val);
    }
  }

  @override
  String? validate(String? value) {
    if (value == null) return 'Value required';
    try {
      int val = int.parse(value);
      if (val < 1) {
        return 'Should be a natural number';
      }
    } catch (e) {
      return 'Must be a number';
    }
  }

  @override
  String getInitialValue() {
    return appSettings.maxNetworkSize.toString();
  }
}
