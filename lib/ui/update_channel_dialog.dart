import 'package:flutter/material.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';

/// Where the user chose to pick up the new version.
enum UpdateChannel { github, store }

/// Asks which channel to update from, after saying why they differ.
///
/// A release reaches the stores only after it is hand-tested, published and
/// reviewed there, so a store install trails GitHub by days. The snackbar
/// cannot say that without turning into a wall of text.
class UpdateChannelDialog extends StatelessWidget {
  const UpdateChannelDialog({super.key, this.storeLabel});

  /// Name of the store for this platform, or null when it has no store build.
  final String? storeLabel;

  static Future<UpdateChannel?> show(
    BuildContext context, {
    String? storeLabel,
  }) {
    return showAdaptiveDialog<UpdateChannel>(
      context: context,
      builder: (context) => UpdateChannelDialog(storeLabel: storeLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = storeLabel;
    return AdaptiveDialog(
      title: const Text('Where to get the update'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GitHub carries a new version the day it ships, so it is the '
            'fastest way to get features and fixes.',
          ),
          const SizedBox(height: 12),
          Text(
            store == null
                ? 'Stores get it later: every release has to be tested and '
                    'published by hand, and the store reviews it again before '
                    'it reaches you.'
                : '$store gets it only once that release is tested, published '
                    'and approved there, which can take a few days.',
          ),
        ],
      ),
      actions: [
        if (store != null)
          AdaptiveDialogAction(
            onPressed: () => Navigator.pop(context, UpdateChannel.store),
            child: Text(store),
          ),
        AdaptiveDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, UpdateChannel.github),
          child: const Text('GitHub'),
        ),
      ],
    );
  }
}
