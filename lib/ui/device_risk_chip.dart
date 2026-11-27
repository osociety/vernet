import 'package:flutter/material.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/utils/localization.dart';

/// The risk tier of a device as a small green, amber or red chip.
///
/// The tooltip names every reason behind the tier, so a Medium or High chip is
/// never unexplained.
class DeviceRiskChip extends StatelessWidget {
  const DeviceRiskChip({
    super.key,
    required this.level,
    this.reasons = const [],
  });

  final DeviceRiskLevel level;
  final List<DeviceRiskReason> reasons;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (level) {
      DeviceRiskLevel.low => colors.success,
      DeviceRiskLevel.medium => colors.warning,
      DeviceRiskLevel.high => colors.critical,
    };
    return Tooltip(
      message: _tooltip(context.l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              _label(context.l10n),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (level) {
        DeviceRiskLevel.low => l10n.deviceRiskLevelLow,
        DeviceRiskLevel.medium => l10n.deviceRiskLevelMedium,
        DeviceRiskLevel.high => l10n.deviceRiskLevelHigh,
      };

  String _tooltip(AppLocalizations l10n) {
    if (reasons.isEmpty) return l10n.deviceRiskLowDescription;
    return reasons.map((reason) => _reasonLabel(l10n, reason)).join('\n');
  }

  static String _reasonLabel(AppLocalizations l10n, DeviceRiskReason reason) =>
      switch (reason) {
        DeviceRiskReason.vulnerableService =>
          l10n.deviceRiskReasonVulnerableService,
        DeviceRiskReason.unknownVendor => l10n.deviceRiskReasonUnknownVendor,
        DeviceRiskReason.intermittentPresence =>
          l10n.deviceRiskReasonIntermittent,
        DeviceRiskReason.unknownDeviceType =>
          l10n.deviceRiskReasonUnknownDeviceType,
        DeviceRiskReason.unusualPorts => l10n.deviceRiskReasonUnusualPorts,
      };
}
