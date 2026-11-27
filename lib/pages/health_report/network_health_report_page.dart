import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/network_health_report.dart';
import 'package:vernet/services/network_analysis/network_health_report_service.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/utils/localization.dart';

/// The full-page health report of one scan.
///
/// The page rebuilds the findings from the scan's stored device rows and saves
/// the summary it shows, so the trend compares against the previous scan even
/// when that report was never opened.
class NetworkHealthReportPage extends StatefulWidget {
  const NetworkHealthReportPage({
    super.key,
    required this.scan,
    this.service,
  });

  final ScanData scan;

  /// Injected by tests; production resolves the service from the DI graph.
  final NetworkHealthReportService? service;

  @override
  State<NetworkHealthReportPage> createState() =>
      _NetworkHealthReportPageState();
}

class _NetworkHealthReportPageState extends State<NetworkHealthReportPage> {
  NetworkHealthReportService? _service;
  NetworkHealthReport? _report;
  late Future<NetworkHealthReport> _future;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _service = widget.service ??
        (getIt.isRegistered<NetworkHealthReportService>()
            ? getIt<NetworkHealthReportService>()
            : null);
    _future = _load();
  }

  Future<NetworkHealthReport> _load() async {
    final service = _service;
    if (service == null) throw StateError('No health report service');
    final report = await service.buildForStoredScan(widget.scan, context.l10n);
    unawaited(_save(service, report));
    if (mounted) setState(() => _report = report);
    return report;
  }

  /// A failed snapshot must not take the report down with it.
  Future<void> _save(
    NetworkHealthReportService service,
    NetworkHealthReport report,
  ) async {
    try {
      await service.save(report);
    } catch (error) {
      debugPrint('Health report snapshot failed: $error');
    }
  }

  Future<void> _copy() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: networkHealthReportText(report, context.l10n),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.healthReportCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.healthReportTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.healthReportCopyTooltip,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _report == null ? null : _copy,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<NetworkHealthReport>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = snapshot.data;
            if (snapshot.hasError || report == null) {
              return Center(child: Text(context.l10n.healthReportLoadError));
            }
            return _ReportBody(report: report);
          },
        ),
      ),
    );
  }
}

/// The plain-text form the copy action puts on the clipboard.
String networkHealthReportText(
  NetworkHealthReport report,
  AppLocalizations l10n,
) {
  final buffer = StringBuffer()
    ..writeln(l10n.healthReportTitle)
    ..writeln(
        l10n.healthReportTextGrade(report.grade.letter, '${report.score}'))
    ..writeln(
      l10n.healthReportTextDevices(
        '${report.deviceCount}',
        '${report.lowRiskDevices}',
        '${report.mediumRiskDevices}',
        '${report.highRiskDevices}',
      ),
    )
    ..writeln()
    ..writeln(
      '${l10n.healthReportCriticalTitle} (${report.critical.length})',
    );
  _writeFindings(buffer, report.critical);
  buffer
    ..writeln()
    ..writeln('${l10n.healthReportWarningTitle} (${report.warnings.length})');
  _writeFindings(buffer, report.warnings);
  buffer
    ..writeln()
    ..writeln('${l10n.healthReportInfoTitle} (${report.infos.length})');
  _writeFindings(buffer, report.infos);
  return buffer.toString().trimRight();
}

void _writeFindings(StringBuffer buffer, List<HealthFinding> findings) {
  if (findings.isEmpty) return;
  for (final entry in findings) {
    buffer.writeln(
      '- ${entry.deviceLabel} (${entry.address}): '
      '${entry.finding.title} — ${entry.finding.description}',
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final NetworkHealthReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 700 ? 24.0 : 16.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
              children: [
                _GradeCard(report: report),
                const SizedBox(height: 16),
                _FindingSection(
                  title: context.l10n.healthReportCriticalTitle,
                  icon: Icons.dangerous_outlined,
                  color: Theme.of(context).colorScheme.critical,
                  findings: report.critical,
                ),
                const SizedBox(height: 16),
                _FindingSection(
                  title: context.l10n.healthReportWarningTitle,
                  icon: Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.warning,
                  findings: report.warnings,
                ),
                const SizedBox(height: 16),
                _FindingSection(
                  title: context.l10n.healthReportInfoTitle,
                  icon: Icons.info_outline,
                  color: Theme.of(context).colorScheme.info,
                  findings: report.infos,
                ),
                const SizedBox(height: 16),
                _DeviceSummaryCard(report: report),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.report});

  final NetworkHealthReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final grade = report.grade;
    final color = switch (grade) {
      HealthGrade.a || HealthGrade.b => colors.success,
      HealthGrade.c => colors.warning,
      HealthGrade.d || HealthGrade.f => colors.critical,
    };
    final description = switch (grade) {
      HealthGrade.a => context.l10n.healthReportGradeA,
      HealthGrade.b => context.l10n.healthReportGradeB,
      HealthGrade.c => context.l10n.healthReportGradeC,
      HealthGrade.d => context.l10n.healthReportGradeD,
      HealthGrade.f => context.l10n.healthReportGradeF,
    };
    final (trendIcon, trendColor, trendLabel) = switch (report.trend) {
      HealthTrendDirection.improving => (
          Icons.trending_up,
          colors.success,
          context.l10n.healthReportTrendImproving,
        ),
      HealthTrendDirection.degrading => (
          Icons.trending_down,
          colors.critical,
          context.l10n.healthReportTrendDegrading,
        ),
      HealthTrendDirection.stable => (
          Icons.trending_flat,
          colors.onSurfaceVariant,
          context.l10n.healthReportTrendStable,
        ),
      HealthTrendDirection.unknown => (
          Icons.remove,
          colors.onSurfaceVariant,
          context.l10n.healthReportTrendUnknown,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                grade.letter,
                style: textTheme.displaySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  context.l10n.healthReportScoreOf('${report.score}'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(trendIcon, size: 16, color: trendColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        trendLabel,
                        style: textTheme.bodySmall?.copyWith(color: trendColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingSection extends StatelessWidget {
  const _FindingSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.findings,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<HealthFinding> findings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
              Text(
                '${findings.length}',
                style: textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          if (findings.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.healthReportNoFindings,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          for (final entry in findings) ...[
            const SizedBox(height: 12),
            Divider(color: colors.outlineVariant, height: 1),
            const SizedBox(height: 12),
            Text(entry.finding.title, style: textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              '${entry.deviceLabel} · ${entry.address}',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.finding.description, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _DeviceSummaryCard extends StatelessWidget {
  const _DeviceSummaryCard({required this.report});

  final NetworkHealthReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.healthReportDeviceSummary,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TierCount(
                label: context.l10n.deviceRiskLevelLow,
                count: report.lowRiskDevices,
                color: colors.success,
              ),
              _TierCount(
                label: context.l10n.deviceRiskLevelMedium,
                count: report.mediumRiskDevices,
                color: colors.warning,
              ),
              _TierCount(
                label: context.l10n.deviceRiskLevelHigh,
                count: report.highRiskDevices,
                color: colors.critical,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.healthReportNotableDevices,
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (report.notableDevices.isEmpty)
            Text(
              context.l10n.healthReportNoHighRisk,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (final label in report.notableDevices)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: colors.critical),
                    const SizedBox(width: 6),
                    Flexible(child: Text(label, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TierCount extends StatelessWidget {
  const _TierCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Text('$label $count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
