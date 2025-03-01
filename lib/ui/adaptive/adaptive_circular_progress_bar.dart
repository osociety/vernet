import 'package:flutter/material.dart';
import 'package:vernet/values/globals.dart' as globals;

class AdaptiveCircularProgressIndicator extends StatelessWidget {
  const AdaptiveCircularProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (globals.testingActive) {
      return const Text('Loading..');
    }
    return const CircularProgressIndicator.adaptive();
  }
}
