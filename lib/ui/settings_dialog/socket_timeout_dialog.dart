import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/strings.dart';

import '../../ui/base_settings_dialog.dart';

class SocketTimeoutDialog extends StatefulWidget {
  const SocketTimeoutDialog({Key? key}) : super(key: key);

  @override
  _SocketTimeoutDialogState createState() => _SocketTimeoutDialogState();
}

class _SocketTimeoutDialogState
    extends BaseSettingsDialog<SocketTimeoutDialog> {
  @override
  String getDialogTitle() {
    return StringValue.SOCKET_TIMEOUT;
  }

  @override
  String getHintText() {
    return StringValue.SOCKET_TIMEOUT_DESC;
  }

  @override
  TextInputType getKeyBoardType() {
    return TextInputType.number;
  }

  @override
  void onSubmit(String value) {
    int val = int.parse(value);
    if (val != appSettings.socketTimeout) {
      print('saving value');
      appSettings.setSocketTimeout(val);
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
    return appSettings.socketTimeout.toString();
  }
}
