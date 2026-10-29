import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/strings.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({
    super.key,
    this.scanRepository,
    this.deviceRepository,
  });

  final ScanRepository? scanRepository;
  final DeviceRepository? deviceRepository;

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late final ScanRepository _scanRepository;
  late final DeviceRepository _deviceRepository;
  late Future<List<_ScanSummary>> _scansFuture;

  @override
  void initState() {
    super.initState();
    _scanRepository = widget.scanRepository ?? getIt<ScanRepository>();
    _deviceRepository = widget.deviceRepository ?? getIt<DeviceRepository>();
    _scansFuture = _loadScans();
  }

  Future<List<_ScanSummary>> _loadScans() async {
    final scans = await _scanRepository.getRecentScans();
    final counts = await Future.wait(
      scans.map((scan) => _deviceRepository.countByScanId(scan.id)),
    );
    return [
      for (var index = 0; index < scans.length; index++)
        _ScanSummary(scan: scans[index], deviceCount: counts[index]),
    ];
  }

  void _reload() {
    setState(() {
      _scansFuture = _loadScans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.previousScansTitle),
        actions: [
          IconButton(
            tooltip: StringValue.scanHistoryRefresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<_ScanSummary>>(
        future: _scansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageView(
              message: StringValue.scanHistoryLoadError,
              onRetry: _reload,
            );
          }
          final summaries = snapshot.data ?? const <_ScanSummary>[];
          if (summaries.isEmpty) {
            return _HistoryEmptyState(onRefresh: _reload);
          }
          return _ResponsiveBody(
            maxWidth: 1100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ScanActivityOverview(summaries: summaries),
                      const SizedBox(height: 20),
                      _ScanHistoryPanel(
                        summaries: summaries,
                        isWide: isWide,
                        onScanTap: _openScan,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openScan(_ScanSummary summary) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ScanDetailPage(
          scan: summary.scan,
          deviceRepository: _deviceRepository,
        ),
      ),
    );
  }
}

class _ScanActivityOverview extends StatelessWidget {
  const _ScanActivityOverview({required this.summaries});

  final List<_ScanSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalDevices =
        summaries.fold<int>(0, (total, summary) => total + summary.deviceCount);
    final latestScan = summaries.first.scan.startTime;
    final deviceCounts = [
      for (final summary in summaries) summary.deviceCount,
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            StringValue.scanHistoryOverviewTitle.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OverviewStat(
                  label: StringValue.scanHistoryScansLabel,
                  value: '${summaries.length}',
                ),
              ),
              const _OverviewDivider(),
              Expanded(
                child: _OverviewStat(
                  label: StringValue.scanHistoryDevicesFoundLabel,
                  value: '$totalDevices',
                ),
              ),
              const _OverviewDivider(),
              Expanded(
                child: _OverviewStat(
                  label: StringValue.scanHistoryLatestScanLabel,
                  value: _relativeTime(latestScan),
                ),
              ),
            ],
          ),
          if (deviceCounts.length > 1) ...[
            const SizedBox(height: 20),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    StringValue.scanHistoryDevicesPerScanLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _ScanActivityBars(counts: deviceCounts),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  const _OverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _ScanActivityBars extends StatelessWidget {
  const _ScanActivityBars({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recent = counts.take(12).toList().reversed.toList();
    final maxCount = recent.fold<int>(1, math.max);

    return Semantics(
      label:
          '${StringValue.scanHistoryDevicesPerScanLabel}: ${counts.join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < recent.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6 + (recent[index] / maxCount) * 28,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: index == recent.length - 1 ? 0.9 : 0.35,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanHistoryPanel extends StatelessWidget {
  const _ScanHistoryPanel({
    required this.summaries,
    required this.isWide,
    required this.onScanTap,
  });

  final List<_ScanSummary> summaries;
  final bool isWide;
  final ValueChanged<_ScanSummary> onScanTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    StringValue.scanHistoryListTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ResultCountBadge(count: summaries.length),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          if (isWide) ...[
            const _ScanTableHeader(),
            Divider(height: 1, color: colors.outlineVariant),
          ],
          for (var index = 0; index < summaries.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            if (isWide)
              _DesktopScanRow(
                summary: summaries[index],
                onTap: () => onScanTap(summaries[index]),
              )
            else
              _MobileScanRow(
                summary: summaries[index],
                onTap: () => onScanTap(summaries[index]),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScanTableHeader extends StatelessWidget {
  const _ScanTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                StringValue.scanHistoryNetworkColumn.toUpperCase(),
                style: style,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              StringValue.scanHistoryStartedColumn.toUpperCase(),
              style: style,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              StringValue.scanHistoryDurationColumn.toUpperCase(),
              style: style,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              StringValue.scanHistoryDevicesColumn.toUpperCase(),
              style: style,
            ),
          ),
          SizedBox(
            width: 104,
            child: Text(
              StringValue.scanHistoryStatusColumn.toUpperCase(),
              style: style,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _DesktopScanRow extends StatelessWidget {
  const _DesktopScanRow({required this.summary, required this.onTap});

  final _ScanSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scan = summary.scan;
    final inProgress = scan.onGoing == true;
    final duration = _formatDuration(scan.startTime, scan.endTime);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _ScanAvatar(inProgress: inProgress),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network ${scan.gatewayIp}',
                          style: textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _relativeTime(scan.startTime),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatTimestamp(scan.startTime),
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                duration.isEmpty ? '—' : duration,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text('${summary.deviceCount}', style: textTheme.bodyMedium),
                ],
              ),
            ),
            SizedBox(
              width: 104,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(inProgress: inProgress),
              ),
            ),
            const SizedBox(
              width: 24,
              child: Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileScanRow extends StatelessWidget {
  const _MobileScanRow({required this.summary, required this.onTap});

  final _ScanSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scan = summary.scan;
    final inProgress = scan.onGoing == true;
    final duration = _formatDuration(scan.startTime, scan.endTime);
    return AdaptiveListTile(
      leading: _ScanAvatar(inProgress: inProgress),
      title: Text('Network ${scan.gatewayIp}'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MetaChip(
              icon: Icons.schedule,
              label: _relativeTime(scan.startTime),
            ),
            _MetaChip(
              icon: Icons.devices_other,
              label: _deviceCountLabel(summary.deviceCount),
            ),
            if (duration.isNotEmpty)
              _MetaChip(icon: Icons.timer_outlined, label: duration),
          ],
        ),
      ),
      trailing: _StatusChip(inProgress: inProgress),
      onTap: onTap,
    );
  }
}

class _ScanAvatar extends StatelessWidget {
  const _ScanAvatar({required this.inProgress});

  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        inProgress ? Icons.sync : Icons.history,
        size: 20,
        color: colors.primary,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.radar, size: 34, color: colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              StringValue.scanHistoryEmptyTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              StringValue.scanHistoryEmptyPlaceholder,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text(StringValue.scanHistoryRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanDetailPage extends StatefulWidget {
  const ScanDetailPage({
    super.key,
    required this.scan,
    this.deviceRepository,
  });

  final ScanData scan;
  final DeviceRepository? deviceRepository;

  @override
  State<ScanDetailPage> createState() => _ScanDetailPageState();
}

class _ScanDetailPageState extends State<ScanDetailPage> {
  late final DeviceRepository _deviceRepository;
  late final Future<List<DeviceData>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _deviceRepository = widget.deviceRepository ?? getIt<DeviceRepository>();
    _devicesFuture = _deviceRepository.getListForScan(widget.scan.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringValue.scanReportTitle)),
      body: FutureBuilder<List<DeviceData>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text(StringValue.scanReportLoadError));
          }
          final devices = snapshot.data ?? const <DeviceData>[];
          return _ResponsiveBody(
            maxWidth: 1100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final summary = _ScanSummaryCard(
                  scan: widget.scan,
                  deviceCount: devices.length,
                );
                final results = _DeviceResultsPanel(
                  devices: devices,
                  isWide: isWide,
                  onDeviceTap: _openDevice,
                );
                return SingleChildScrollView(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 340, child: summary),
                            const SizedBox(width: 24),
                            Expanded(child: results),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 20),
                            results,
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openDevice(DeviceData device) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => DeviceDetailPage(device: device),
      ),
    );
  }
}

class _ResponsiveBody extends StatelessWidget {
  const _ResponsiveBody({required this.child, this.maxWidth = 900});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 700 ? 24.0 : 16.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _ScanSummaryCard extends StatelessWidget {
  const _ScanSummaryCard({required this.scan, required this.deviceCount});

  final ScanData scan;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inProgress = scan.onGoing == true;
    final duration = _formatDuration(scan.startTime, scan.endTime);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network ${scan.gatewayIp}',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inProgress
                          ? StringValue.scanReportInProgress
                          : StringValue.scanReportCompleted,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(inProgress: inProgress),
            ],
          ),
          const SizedBox(height: 24),
          Center(child: _ScanRadar(deviceCount: deviceCount)),
          const SizedBox(height: 16),
          Text(
            '${_deviceCountLabel(deviceCount)} found',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 12),
          Text(
            StringValue.scanReportScanWindow.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _ScanTimelineRow(
            icon: Icons.play_arrow_rounded,
            label: StringValue.scanReportStarted,
            value: _formatTimestamp(scan.startTime),
          ),
          _ScanTimelineRow(
            icon: Icons.stop_rounded,
            label: StringValue.scanReportEnded,
            value: scan.endTime == null
                ? StringValue.scanReportStillRunning
                : _formatTimestamp(scan.endTime),
          ),
          if (duration.isNotEmpty)
            _ScanTimelineRow(
              icon: Icons.timer_outlined,
              label: StringValue.scanReportDuration,
              value: duration,
            ),
        ],
      ),
    );
  }
}

class _ScanRadar extends StatelessWidget {
  const _ScanRadar({required this.deviceCount});

  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '${_deviceCountLabel(deviceCount)} found',
      excludeSemantics: true,
      child: SizedBox(
        width: 196,
        height: 196,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(196),
              painter: _ScanRadarPainter(
                color: colors.primary,
                outlineColor: colors.outlineVariant,
                deviceCount: deviceCount,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$deviceCount',
                  style: textTheme.displaySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (deviceCount == 1
                          ? StringValue.scanReportDeviceLabel
                          : StringValue.scanReportDevicesLabel)
                      .toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanRadarPainter extends CustomPainter {
  _ScanRadarPainter({
    required this.color,
    required this.outlineColor,
    required this.deviceCount,
  });

  final Color color;
  final Color outlineColor;
  final int deviceCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outlineColor.withValues(alpha: 0.55);
    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(center, radius * ring / 3, ringPaint);
    }

    final axisPaint = Paint()
      ..strokeWidth = 1
      ..color = outlineColor.withValues(alpha: 0.35);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      axisPaint,
    );

    canvas.drawCircle(
      center,
      7,
      Paint()..color = color.withValues(alpha: 0.2),
    );
    canvas.drawCircle(center, 3, Paint()..color = color);

    final visibleDots = deviceCount.clamp(0, 12);
    if (visibleDots == 0) return;

    final glowPaint = Paint()..color = color.withValues(alpha: 0.16);
    final dotPaint = Paint()..color = color;
    for (var index = 0; index < visibleDots; index++) {
      final angle = -math.pi / 2 + (2 * math.pi * index) / visibleDots;
      final ringRadius = radius * (0.45 + (index % 3) * 0.18);
      final dotCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * ringRadius;
      canvas.drawCircle(dotCenter, 9, glowPaint);
      canvas.drawCircle(dotCenter, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanRadarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.deviceCount != deviceCount;
}

class _ScanTimelineRow extends StatelessWidget {
  const _ScanTimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceResultsPanel extends StatelessWidget {
  const _DeviceResultsPanel({
    required this.devices,
    required this.isWide,
    required this.onDeviceTap,
  });

  final List<DeviceData> devices;
  final bool isWide;
  final ValueChanged<DeviceData> onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(Icons.devices_other, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    StringValue.scanReportDiscoveredDevices,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ResultCountBadge(count: devices.length),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.devices_other_outlined,
                    size: 32,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    StringValue.scanReportNoDevices,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            if (isWide) ...[
              const _DeviceTableHeader(),
              Divider(height: 1, color: colors.outlineVariant),
            ],
            for (var index = 0; index < devices.length; index++) ...[
              if (index > 0) Divider(height: 1, color: colors.outlineVariant),
              if (isWide)
                _DesktopDeviceRow(
                  device: devices[index],
                  onTap: () => onDeviceTap(devices[index]),
                )
              else
                _MobileDeviceRow(
                  device: devices[index],
                  onTap: () => onDeviceTap(devices[index]),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeviceTableHeader extends StatelessWidget {
  const _DeviceTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                StringValue.scanReportDeviceColumn.toUpperCase(),
                style: style,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              StringValue.scanReportIpColumn.toUpperCase(),
              style: style,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              StringValue.scanReportMacColumn.toUpperCase(),
              style: style,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _DesktopDeviceRow extends StatelessWidget {
  const _DesktopDeviceRow({required this.device, required this.onTap});

  final DeviceData device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final macAddress = device.macAddress;
    final hasMac = macAddress != null && macAddress.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _DeviceAvatar(device: device),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DeviceUtil.getDeviceMake(device) ??
                          StringValue.unknownDevice,
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                device.internetAddress,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                hasMac ? macAddress : '—',
                style: textTheme.bodyMedium?.copyWith(
                  color: hasMac ? null : colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(
              width: 24,
              child: Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDeviceRow extends StatelessWidget {
  const _MobileDeviceRow({required this.device, required this.onTap});

  final DeviceData device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final macAddress = device.macAddress;
    final subtitle = macAddress == null || macAddress.isEmpty
        ? device.internetAddress
        : '${device.internetAddress} • $macAddress';
    return AdaptiveListTile(
      leading: _DeviceAvatar(device: device),
      title: Text(
        DeviceUtil.getDeviceMake(device) ?? StringValue.unknownDevice,
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _DeviceAvatar extends StatelessWidget {
  const _DeviceAvatar({required this.device});

  final DeviceData device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        DeviceUtil.getIconData(device),
        size: 20,
        color: colors.primary,
      ),
    );
  }
}

class _ResultCountBadge extends StatelessWidget {
  const _ResultCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.inProgress});

  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = inProgress ? colorScheme.tertiary : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              inProgress
                  ? StringValue.scanReportInProgress
                  : StringValue.scanReportCompleted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ScanSummary {
  const _ScanSummary({required this.scan, required this.deviceCount});

  final ScanData scan;
  final int deviceCount;
}

String _deviceCountLabel(int count) =>
    '$count ${count == 1 ? 'device' : 'devices'}';

String _relativeTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return _formatShortDate(local);
}

String _formatShortDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final year = value.year == DateTime.now().year ? '' : ' ${value.year}';
  return '${value.day} ${months[value.month - 1]}$year';
}

String _formatTimestamp(DateTime? value) {
  if (value == null) {
    return 'unknown time';
  }
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _formatDuration(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return '';
  }
  final seconds = end.difference(start).inSeconds;
  if (seconds < 0) {
    return '';
  }
  if (seconds < 60) {
    return '${seconds}s';
  }
  return '${seconds ~/ 60}m ${seconds % 60}s';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
