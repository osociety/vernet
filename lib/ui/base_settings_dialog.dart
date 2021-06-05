import 'package:flutter/material.dart';

abstract class BaseSettingsDialog<T extends StatefulWidget> extends State<T> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  final _fieldKey = GlobalKey();
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
    return AlertDialog(
      title: Text(getDialogTitle()),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: _fieldKey,
          controller: _controller,
          validator: validate,
          keyboardType: getKeyBoardType(),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: getHintText(),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              onSubmit(_controller.text);
              Navigator.pop(context);
            }
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
