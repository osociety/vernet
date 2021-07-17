import 'package:flutter/material.dart';

class PopularChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PopularChip({Key? key, required this.label, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(2.0),
      child: ActionChip(
        backgroundColor: Theme.of(context).accentColor.withAlpha(20),
        label: Text(
          label,
          style: TextStyle(color: Theme.of(context).accentColor),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
