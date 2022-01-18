import 'package:flutter/material.dart';

class CustomTile extends StatelessWidget {
  const CustomTile({Key? key, required this.leading, required this.child})
      : super(key: key);

  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Row(
          children: [leading, const SizedBox(width: 8), Expanded(child: child)],
        ),
      ],
    );
  }
}
