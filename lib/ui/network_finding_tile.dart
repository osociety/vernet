import 'package:flutter/material.dart';
import 'package:vernet/models/network_finding.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/utils/localization.dart';

/// One security finding, colored by severity.
class NetworkFindingTile extends StatelessWidget {
  const NetworkFindingTile({super.key, required this.finding});

  final NetworkFinding finding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (finding.severity) {
      NetworkFindingSeverity.critical => colors.critical,
      NetworkFindingSeverity.warning => colors.warning,
      NetworkFindingSeverity.info => colors.info,
    };
    final icon = switch (finding.severity) {
      NetworkFindingSeverity.critical => Icons.error_outline,
      NetworkFindingSeverity.warning => Icons.warning_amber_rounded,
      NetworkFindingSeverity.info => Icons.info_outline,
    };
    final label = switch (finding.severity) {
      NetworkFindingSeverity.critical => context.l10n.securitySeverityCritical,
      NetworkFindingSeverity.warning => context.l10n.securitySeverityWarning,
      NetworkFindingSeverity.info => context.l10n.securitySeverityInfo,
    };
    return AdaptiveListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 8,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        finding.title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(finding.description),
      trailing: _SeverityChip(label: label, color: color),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
