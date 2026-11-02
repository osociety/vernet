import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';

/// Small muted clock-plus-timestamp shown next to a card title to indicate
/// when the card's data was last measured.
class TimestampChip extends StatelessWidget {
  const TimestampChip({super.key, required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 13,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            formatTimestamp(timestamp),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
