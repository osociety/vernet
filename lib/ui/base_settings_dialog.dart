import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';
import 'package:vernet/values/keys.dart';

abstract class BaseSettingsDialog<T extends StatefulWidget> extends State<T> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  String getDialogTitle();
  String getHintText();
  TextInputType getKeyBoardType();

  void onSubmit(String value);

  String getInitialValue();

  String? validate(String? value);
  @override
  void initState() {
    super.initState();
    _controller.text = getInitialValue();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: title,
      content: content,
      actions: actions(context),
    );
  }

  Widget get title => Text(getDialogTitle());
  Widget get content => Form(
        key: _formKey,
        child: Platform.isIOS || Platform.isMacOS
            ? CupertinoTextFormFieldRow(
                key: WidgetKey.settingsTextField.key,
                controller: _controller,
                validator: validate,
                keyboardType: getKeyBoardType(),
                placeholder: getHintText(),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 2.0,
                    color: CupertinoColors.inactiveGray,
                  ),
                  borderRadius: BorderRadius.circular(32.0),
                ),
              )
            : TextFormField(
                key: WidgetKey.settingsTextField.key,
                controller: _controller,
                validator: validate,
                keyboardType: getKeyBoardType(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: getHintText(),
                ),
              ),
      );
  List<Widget> actions(BuildContext context) {
    return [
      AdaptiveDialogAction(
        key: WidgetKey.settingsSubmitButton.key,
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            onSubmit(_controller.text);
            Navigator.pop(context);
          }
        },
        isDestructiveAction: true,
        child: const Text('Submit'),
      ),
    ];
  }
}
