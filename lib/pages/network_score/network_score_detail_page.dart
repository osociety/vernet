import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/score_display.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/pages/speed_test/speed_test_page.dart';
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/services/server_monitor_service.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/utils/localization.dart';

/// Spliced into a localized factor template to find where its placeholders
/// begin; see [_NetworkScoreDetailViewState._hasFactor].
const String _factorSentinel = '\u0000';

class NetworkScoreDetailPage extends StatelessWidget {
  const NetworkScoreDetailPage({super.key, required this.initialScore});

  final NetworkScore initialScore;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<NetworkScoreBloc>(),
      child: _NetworkScoreDetailView(initialScore: initialScore),
    );
  }
}

class _NetworkScoreDetailView extends StatefulWidget {
  const _NetworkScoreDetailView({required this.initialScore});

  final NetworkScore initialScore;

  @override
  State<_NetworkScoreDetailView> createState() =>
      _NetworkScoreDetailViewState();
}

class _NetworkScoreDetailViewState extends State<_NetworkScoreDetailView> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkScoreBloc, NetworkScoreState>(
      builder: (context, state) {
        final currentScore = state.maybeWhen(
          success: (score) => score,
          orElse: () => widget.initialScore,
        );
        final isComputing = state.maybeWhen(
          computing: () => true,
          orElse: () => false,
        );
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.networkScoreTitle),
            actions: [
              IconButton(
                icon: isComputing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            AdaptiveCircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: l10n.scoreRefreshTooltip,
                onPressed: isComputing ? null : () => _refreshScore(context),
              ),
            ],
          ),
          body: SafeArea(
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverallScoreSection(context, currentScore, isComputing),
              const SizedBox(height: 24),
              _buildDimensionsSection(context, currentScore),
              const SizedBox(height: 24),
              _buildImproveScoreSection(context, currentScore),
            ],
          )),
        );
      },
    );
  }

  Widget _buildOverallScoreSection(
      BuildContext context, NetworkScore currentScore, bool isComputing) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final scoreColor = _getScoreColor(currentScore.overallScore, colors);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        children: [
          if (isComputing)
            const SizedBox(
              width: 100,
              height: 100,
              child: AdaptiveCircularProgressIndicator(strokeWidth: 6),
            )
          else
            _ScoreGauge(score: currentScore.overallScore, color: scoreColor),
          const SizedBox(height: 16),
          Text(
            _getScoreLevelText(context, currentScore.level),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreDescription(context, currentScore.level),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.scoreLastComputed(
              DateFormat.yMMMd(l10n.localeName)
                  .add_jm()
                  .format(currentScore.computedAt),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withAlpha(180),
                ),
          ),
          if (currentScore.metadata['stalenessDecay'] != null) ...[
            const SizedBox(height: 12),
            _buildStalenessWarning(context, currentScore, colors),
          ],
        ],
      ),
    );
  }

  Widget _buildDimensionsSection(
      BuildContext context, NetworkScore currentScore) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scoreBreakdown,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ...currentScore.dimensions.map((dim) => _buildDimensionTile(
              context,
              dim,
              _getScoreColor(dim.value, colors),
            )),
      ],
    );
  }

  Widget _buildDimensionTile(
    BuildContext context,
    DimensionScore dimension,
    Color color,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withAlpha(80)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getDimensionIcon(dimension.name),
                  color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scoreDimensionName(context.l10n, dimension.name),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    dimension.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _DimensionScoreBadge(score: dimension.value, color: color),
          ],
        ),
        children: [
          _DimensionBar(value: dimension.value, color: color),
          const SizedBox(height: 12),
          _buildFactorSections(context, dimension.factors, colors),
        ],
      ),
    );
  }

  Widget _buildFactorSections(
    BuildContext context,
    List<String> factors,
    ColorScheme colors,
  ) {
    final l10n = context.l10n;
    final parsedFactors = _parseFactorsWithPoints(factors);
    final gainedPoints = parsedFactors.where((f) => f.points > 0).toList();
    final deductedPoints = parsedFactors.where((f) => f.points < 0).toList();
    final neutralPoints = parsedFactors.where((f) => f.points == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gainedPoints.isNotEmpty) ...[
          Text(
            l10n.scoreFactorsGood,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...gainedPoints.map((factor) => _buildFactorItemWithPoints(
                context,
                factor,
                colors,
                true,
              )),
          if (deductedPoints.isNotEmpty || neutralPoints.isNotEmpty)
            const SizedBox(height: 12),
        ],
        if (deductedPoints.isNotEmpty) ...[
          Text(
            l10n.scoreFactorsImprove,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...deductedPoints.map((factor) => _buildFactorItemWithPoints(
                context,
                factor,
                colors,
                false,
              )),
          if (neutralPoints.isNotEmpty) const SizedBox(height: 12),
        ],
        if (neutralPoints.isNotEmpty) ...[
          Text(
            l10n.scoreFactorsInfo,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...neutralPoints.map((factor) => _buildFactorItemWithPoints(
                context,
                factor,
                colors,
                true,
              )),
        ],
      ],
    );
  }

  List<_ParsedFactor> _parseFactorsWithPoints(List<String> factors) {
    // Advice is localized, so the deduction is split off with the word the
    // advice itself uses instead of a hardcoded `points`.
    final unit = RegExp.escape(context.l10n.scorePointsUnit);
    final inParens = RegExp(
      '\\(([^)]*?(-?\\d+)\\s*$unit?)\\)',
      caseSensitive: false,
    );
    final bare = RegExp('(-\\d+)\\s*$unit?', caseSensitive: false);

    return factors.map((factor) {
      final match = inParens.firstMatch(factor);
      if (match != null) {
        return _ParsedFactor(
          text: factor.replaceAll(inParens, '').trim(),
          points: int.parse(match.group(2)!),
        );
      }

      final simpleMatch = bare.firstMatch(factor);
      if (simpleMatch != null) {
        return _ParsedFactor(
          text: factor.replaceAll(bare, '').trim(),
          points: int.parse(simpleMatch.group(1)!),
        );
      }

      return _ParsedFactor(text: factor, points: 0);
    }).toList();
  }

  /// Factors are localized advice lines, so a condition is recognised by the
  /// start of its own line rather than by an English fragment. Passing the
  /// sentinel as the placeholder gives back the template up to the first hole,
  /// which is the part every generated line starts with.
  bool _hasFactor(List<String> factors, String template) {
    final cut = template.indexOf(_factorSentinel);
    final needle = (cut < 0 ? template : template.substring(0, cut)).trim();
    return factors.any((factor) => factor.contains(needle));
  }

  Widget _buildFactorItemWithPoints(
    BuildContext context,
    _ParsedFactor factor,
    ColorScheme colors,
    bool isPositive,
  ) {
    final hasPoints = factor.points != 0;
    final pointText =
        hasPoints ? '${factor.points > 0 ? "+" : ""}${factor.points}' : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            factor.text.startsWith('✓')
                ? Icons.check_circle
                : factor.text.startsWith('✗')
                    ? Icons.error_outline
                    : factor.text.startsWith('~')
                        ? Icons.warning_amber
                        : Icons.info_outline,
            size: 14,
            color: factor.text.startsWith('✓')
                ? Colors.green
                : factor.text.startsWith('✗')
                    ? colors.error
                    : factor.text.startsWith('~')
                        ? Colors.amber
                        : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              factor.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          if (hasPoints) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (factor.points > 0 ? Colors.green : colors.error)
                    .withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pointText!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: factor.points > 0 ? Colors.green : colors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImproveScoreSection(
      BuildContext context, NetworkScore currentScore) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scoreImproveTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        // Security actions
        if (currentScore.security.value < 100) ...[
          _ActionTile(
            icon: Icons.wifi_find,
            title: l10n.scoreActionScanTitle,
            subtitle: currentScore.security.value < 50
                ? l10n.scoreActionScanCritical
                : l10n.scoreActionScanSubtitle,
            color: colors.primary,
            onTap: () => _navigateAndRefresh(context, HostScanPage()),
          ),
          _ActionTile(
            icon: Icons.verified_user,
            title: l10n.scoreActionTrustTitle,
            subtitle: l10n.scoreActionTrustSubtitle,
            color: Colors.green,
            onTap: () =>
                _navigateAndRefresh(context, const TrustedDevicesPage()),
          ),
        ],
        // Health actions
        if (currentScore.health.value < 100)
          _ActionTile(
            icon: Icons.wifi,
            title: l10n.scoreActionWifiTitle,
            subtitle: _getHealthActionSubtitle(context, currentScore.health),
            color: Colors.green,
            onTap: () => _showHealthTips(context),
          ),
        // Reliability actions
        if (currentScore.reliability.value < 100) ...[
          _ActionTile(
            icon: Icons.monitor_heart,
            title: l10n.scoreActionMonitorTitle,
            subtitle: _getReliabilityActionSubtitle(
              context,
              currentScore.reliability,
            ),
            color: colors.secondary,
            onTap: () =>
                _navigateAndRefresh(context, const ServerCheckerPage()),
          ),
          _QuickAddMonitorsSection(
            onAddMonitor: (monitor) => _quickAddMonitor(context, monitor),
          ),
        ],
        // Speed actions
        if (currentScore.speed.value < 100)
          _ActionTile(
            icon: Icons.speed,
            title: l10n.scoreActionSpeedTitle,
            subtitle: currentScore.speed.value < 30
                ? l10n.scoreActionSpeedLow
                : l10n.scoreActionSpeedNormal,
            color: Colors.amber,
            onTap: () => _runSpeedTest(context),
          ),
        // Vulnerabilities actions
        if (currentScore.vulnerabilities.value < 100)
          _ActionTile(
            icon: Icons.security,
            title: l10n.scoreActionReviewTitle,
            subtitle: l10n.scoreActionReviewSubtitle,
            color: colors.error,
            onTap: () => _navigateAndRefresh(context, HostScanPage()),
          ),
      ],
    );
  }

  String _getHealthActionSubtitle(BuildContext context, DimensionScore health) {
    final l10n = context.l10n;
    final factors = health.factors;
    if (_hasFactor(factors, l10n.scoreHealthNoInternet)) {
      return l10n.scoreHealthSubNoInternet;
    }
    if (_hasFactor(factors, l10n.scoreHealthWeakSignal(_factorSentinel))) {
      return l10n.scoreHealthSubWeakSignal;
    }
    if (_hasFactor(factors, l10n.scoreHealthNoGateway)) {
      return l10n.scoreHealthSubNoGateway;
    }
    if (_hasFactor(factors, l10n.scoreHealthLatencyHigh(_factorSentinel))) {
      return l10n.scoreHealthSubLatency;
    }
    return l10n.scoreHealthSubDefault;
  }

  String _getReliabilityActionSubtitle(
      BuildContext context, DimensionScore reliability) {
    final l10n = context.l10n;
    final factors = reliability.factors;
    if (_hasFactor(factors, l10n.scoreReliabilityNoMonitors)) {
      return l10n.scoreReliabilitySubNoMonitors;
    }
    if (_hasFactor(factors, l10n.scoreReliabilityMissingRouter) ||
        _hasFactor(factors, l10n.scoreReliabilityMissingInternet)) {
      return l10n.scoreReliabilitySubMissing;
    }
    return l10n.scoreReliabilitySubDefault;
  }

  Future<void> _quickAddMonitor(
      BuildContext context, ServerMonitor monitor) async {
    final l10n = context.l10n;
    final service = ServerMonitorService();
    final newMonitor = ServerMonitor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: monitor.name,
      host: monitor.host,
      type: monitor.type,
      intervalSeconds: monitor.intervalSeconds,
    );
    await service.saveMonitor(newMonitor);
    getIt<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.scoreMonitorAdded(monitorDisplayName(l10n, monitor.name)),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showHealthTips(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scoreHealthTipsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.scoreHealthTipCloser),
            Text(l10n.scoreHealthTipObstacles),
            Text(l10n.scoreHealthTipInterference),
            Text(l10n.scoreHealthTipCongestion),
            Text(l10n.scoreHealthTipRestart),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _runSpeedTest(BuildContext context) async {
    await _navigateAndRefresh(context, const SpeedTestPage());
  }

  void _refreshScore(BuildContext context) {
    context.read<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
  }

  Future<void> _navigateAndRefresh(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (mounted && context.mounted) {
      _refreshScore(context);
    }
  }

  Widget _buildStalenessWarning(
    BuildContext context,
    NetworkScore score,
    ColorScheme colors,
  ) {
    final l10n = context.l10n;
    final decay = int.tryParse(score.metadata['stalenessDecay'] ?? '0') ?? 0;
    final reason = score.metadata['stalenessReason'] ?? '';
    final lastComputed = score.metadata['lastComputed'] ?? '';

    DateTime? lastComputedTime;
    if (lastComputed.isNotEmpty && lastComputed != 'never') {
      try {
        lastComputedTime = DateTime.parse(lastComputed);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.scoreCardStale,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                if (lastComputedTime != null)
                  Text(
                    l10n.scoreLastFresh(
                      DateFormat.MMMd(l10n.localeName)
                          .add_jm()
                          .format(lastComputedTime),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withAlpha(180),
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-$decay',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score, ColorScheme colors) {
    if (score >= 100) return Colors.green;

    final level = ScoreLevel.fromScore(score);
    switch (level) {
      case ScoreLevel.good:
        return colors.primary;
      case ScoreLevel.moderate:
        return Colors.amber;
      case ScoreLevel.poor:
        return colors.error;
      case ScoreLevel.unknown:
        return colors.onSurfaceVariant;
    }
  }

  String _getScoreLevelText(BuildContext context, ScoreLevel level) {
    final l10n = context.l10n;
    switch (level) {
      case ScoreLevel.good:
        return l10n.scoreLevelGood;
      case ScoreLevel.moderate:
        return l10n.scoreLevelModerate;
      case ScoreLevel.poor:
        return l10n.scoreLevelPoor;
      case ScoreLevel.unknown:
        return l10n.scoreLevelUnknown;
    }
  }

  String _getScoreDescription(BuildContext context, ScoreLevel level) {
    final l10n = context.l10n;
    switch (level) {
      case ScoreLevel.good:
        return l10n.scoreLevelDescGood;
      case ScoreLevel.moderate:
        return l10n.scoreLevelDescModerate;
      case ScoreLevel.poor:
        return l10n.scoreLevelDescPoor;
      case ScoreLevel.unknown:
        return l10n.scoreLevelDescUnknown;
    }
  }

  IconData _getDimensionIcon(String name) {
    switch (name) {
      case 'Security':
        return Icons.security;
      case 'Health':
        return Icons.favorite;
      case 'Reliability':
        return Icons.check_circle_outline;
      case 'Speed':
        return Icons.speed;
      case 'Vulnerabilities':
        return Icons.warning_amber;
      default:
        return Icons.info;
    }
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 10,
              backgroundColor: color.withAlpha(30),
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
              Text(
                context.l10n.scoreOutOf100,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color.withAlpha(180),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DimensionScoreBadge extends StatelessWidget {
  const _DimensionScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$score',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
      ),
    );
  }
}

class _DimensionBar extends StatelessWidget {
  const _DimensionBar({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value / 100,
        minHeight: 8,
        backgroundColor: color.withAlpha(30),
        color: color,
      ),
    );
  }
}

class _QuickAddMonitorsSection extends StatefulWidget {
  const _QuickAddMonitorsSection({required this.onAddMonitor});

  final Future<void> Function(ServerMonitor monitor) onAddMonitor;

  @override
  State<_QuickAddMonitorsSection> createState() =>
      _QuickAddMonitorsSectionState();
}

class _QuickAddMonitorsSectionState extends State<_QuickAddMonitorsSection> {
  List<ServerMonitor> _missingMonitors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMissingMonitors();
  }

  Future<void> _loadMissingMonitors() async {
    final service = ServerMonitorService();
    final monitors = await service.loadMonitors();
    final missing = <ServerMonitor>[];

    final hasRouterMonitor = monitors.any((m) =>
        m.type == ServerCheckType.icmp &&
        m.name.toLowerCase().contains('router'));
    final hasInternetMonitor =
        monitors.any((m) => m.type == ServerCheckType.https);

    if (!hasRouterMonitor) {
      String gatewayIp = '192.168.1.1';
      try {
        final actualGateway = await NetworkInfo().getWifiGatewayIP();
        if (actualGateway != null && actualGateway.isNotEmpty) {
          gatewayIp = actualGateway;
        }
      } catch (e) {
        debugPrint('Failed to get gateway IP: $e');
      }

      missing.add(ServerMonitor(
        id: '',
        name: kLocalRouterSuggestion,
        host: gatewayIp,
        type: ServerCheckType.icmp,
      ));
    }

    if (!hasInternetMonitor) {
      missing.add(const ServerMonitor(
        id: '',
        name: 'Google',
        host: 'google.com',
        type: ServerCheckType.https,
      ));
    }

    if (mounted) {
      setState(() {
        _missingMonitors = missing;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_missingMonitors.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.secondary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: colors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.scoreQuickAddTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSecondaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.scoreQuickAddSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSecondaryContainer.withAlpha(200),
                ),
          ),
          const SizedBox(height: 12),
          ..._missingMonitors.map((monitor) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await widget.onAddMonitor(monitor);
                      await _loadMissingMonitors();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            monitor.type == ServerCheckType.icmp
                                ? Icons.router
                                : Icons.language,
                            color: colors.secondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  monitorDisplayName(l10n, monitor.name),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${monitor.type.name.toUpperCase()} · ${monitor.host}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurface.withAlpha(180),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.add_circle_outline,
                              color: colors.secondary, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParsedFactor {
  const _ParsedFactor({required this.text, required this.points});

  final String text;
  final int points;
}
