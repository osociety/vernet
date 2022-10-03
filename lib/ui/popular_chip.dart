import 'package:flutter/material.dart';

class PopularChip extends StatelessWidget {
  const PopularChip({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      child: ActionChip(
        backgroundColor: Theme.of(context).colorScheme.secondary.withAlpha(20),
        label: Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
