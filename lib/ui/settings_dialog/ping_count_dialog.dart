import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/base_settings_dialog.dart';
import 'package:vernet/values/strings.dart';

class PingCountDialog extends StatefulWidget {
  const PingCountDialog({Key? key}) : super(key: key);

  @override
  _PingCountDialogState createState() => _PingCountDialogState();
}

class _PingCountDialogState extends BaseSettingsDialog<PingCountDialog> {
  @override
  String getDialogTitle() {
    return StringValue.pingCount;
  }

  @override
  String getHintText() {
    return StringValue.pingCountDesc;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    final int val = int.parse(value);
    if (val != appSettings.pingCount) {
      appSettings.setPingCount(val);
    }
  }

  @override
  String? validate(String? value) {
    if (value == null) return 'Value required';
    try {
      final int val = int.parse(value);
      if (val < 1) {
        return 'Should be a natural number';
      }
    } catch (e) {
      return 'Must be a number';
    }
  }

  @override
  String getInitialValue() {
    return appSettings.pingCount.toString();
  }
}
