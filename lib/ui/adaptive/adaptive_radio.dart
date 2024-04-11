import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveRadioButton<T> extends StatelessWidget {
  const AdaptiveRadioButton({
    super.key,
    required this.value,
    required this.groupValue,
    this.onChanged,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS || Platform.isMacOS
        ? CupertinoRadio<T>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
          )
        : Radio<T>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
          );
  }
}
