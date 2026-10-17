import 'package:flutter/material.dart';
import 'package:vernet/values/globals.dart' as globals;

class AdaptiveCircularProgressIndicator extends StatelessWidget {
  const AdaptiveCircularProgressIndicator({super.key, this.strokeWidth});
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (globals.testingActive) {
      return const Text('Getting things ready...');
    }
    return CircularProgressIndicator.adaptive(
      strokeWidth: strokeWidth,
    );
  }
}
