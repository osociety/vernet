import 'package:flutter/material.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';
import 'package:vernet/utils/localization.dart';

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
    final l10n = context.l10n;
    final store = storeLabel;
    return AdaptiveDialog(
      title: Text(l10n.updateChannelTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.updateChannelGithubBody),
          const SizedBox(height: 12),
          Text(store == null
              ? l10n.updateChannelStoresBody
              : l10n.updateChannelStoreBody(store)),
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
