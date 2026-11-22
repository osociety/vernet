import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/utils/device_distribution.dart';
import 'package:vernet/utils/localization.dart';

/// The device distribution of a scan as a strip of colored blocks: one block per host id
/// (last IPv4 octet) of the scanned subnet, first block .1, last block .254 (#36). A found
/// device's block is colored; tapping it opens the device, tapping an empty block says so.
class DeviceDistributionStrip extends StatelessWidget {
  const DeviceDistributionStrip({
    required this.distribution,
    required this.onDeviceTap,
    super.key,
  });

  final DeviceDistribution distribution;

  /// Opens the tapped device, e.g. by pushing its detail page.
  final void Function(DeviceData device) onDeviceTap;

  static const double _blockSize = 14;
  static const double _blockGap = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const pitch = _blockSize + _blockGap;
        final columns = constraints.maxWidth.isFinite
            ? math.max(1, (constraints.maxWidth / pitch).floor())
            : 16;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${l10n.deviceMapTitle} · ${l10n.deviceMapCount(
                  '${distribution.foundCount}',
                  '${DeviceDistribution.blockCount}',
                )}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Wrap(
              spacing: _blockGap,
              runSpacing: _blockGap,
              children: [
                for (final block in distribution.blocks)
                  _Block(
                    key: Key('distribution-block-${block.hostId}'),
                    block: block,
                    address: distribution.addressOf(block.hostId),
                    color: _colorFor(colorScheme, block),
                    onTap: () => _onTap(context, block),
                  ),
              ],
            ),
            // keep the wrap honest about how many columns it lays out
            SizedBox(width: columns * pitch),
          ],
        );
      },
    );
  }

  Color _colorFor(ColorScheme colorScheme, DistributionBlock block) {
    if (!block.isFound) {
      return colorScheme.outlineVariant;
    }
    final device = block.device!;
    if (device.internetAddress == device.currentDeviceIp) {
      return colorScheme.secondary;
    }
    if (device.internetAddress == device.gatewayIp) {
      return colorScheme.tertiary;
    }
    return colorScheme.primary;
  }

  void _onTap(BuildContext context, DistributionBlock block) {
    if (block.isFound) {
      onDeviceTap(block.device!);
      return;
    }
    final l10n = context.l10n;
    final address = distribution.addressOf(block.hostId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(address),
        content: Text(l10n.deviceMapNoDevice(address)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.deviceMapOk),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.address,
    required this.color,
    required this.onTap,
    super.key,
  });

  final DistributionBlock block;
  final String address;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: address,
        child: Container(
          width: DeviceDistributionStrip._blockSize,
          height: DeviceDistributionStrip._blockSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: block.isFound
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
