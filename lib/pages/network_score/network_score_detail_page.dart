import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/pages/speed_test/speed_test_page.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/values/strings.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: const Text(StringValue.networkScoreTitle),
            actions: [
              IconButton(
                icon: isComputing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AdaptiveCircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh score',
                onPressed: isComputing ? null : () => _refreshScore(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverallScoreSection(context, currentScore, isComputing),
              const SizedBox(height: 24),
              _buildDimensionsSection(context, currentScore),
              const SizedBox(height: 24),
              _buildImproveScoreSection(context, currentScore),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallScoreSection(BuildContext context, NetworkScore currentScore, bool isComputing) {
    final colors = Theme.of(context).colorScheme;
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
            _getScoreLevelText(currentScore.level),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreDescription(currentScore.level),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Last computed: ${DateFormat('MMM d, y · h:mm a').format(currentScore.computedAt)}',
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

  Widget _buildDimensionsSection(BuildContext context, NetworkScore currentScore) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Breakdown',
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
              child: Icon(_getDimensionIcon(dimension.name), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dimension.name,
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
    final gainedPoints = factors.where((f) => f.startsWith('✓')).toList();
    final deductedPoints = factors.where((f) => f.startsWith('✗') || f.startsWith('~')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gainedPoints.isNotEmpty) ...[
          Text(
            "What's good",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...gainedPoints.map((factor) => _buildFactorItem(context, factor, colors, true)),
          if (deductedPoints.isNotEmpty) const SizedBox(height: 12),
        ],
        if (deductedPoints.isNotEmpty) ...[
          Text(
            'What needs improvement',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...deductedPoints.map((factor) => _buildFactorItem(context, factor, colors, false)),
        ],
      ],
    );
  }

  Widget _buildFactorItem(
    BuildContext context,
    String factor,
    ColorScheme colors,
    bool isPositive,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPositive ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: isPositive ? Colors.green : colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              factor,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImproveScoreSection(BuildContext context, NetworkScore currentScore) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Improve Your Score',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        // Security actions
        if (currentScore.security.value < 100)
          _ActionTile(
            icon: Icons.wifi_find,
            title: 'Run Network Scan',
            subtitle: currentScore.security.value < 50
                ? 'Critical: Identify unknown devices on your network'
                : 'Discover devices and assess security',
            color: colors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HostScanPage()),
            ),
          ),
        // Health actions
        if (currentScore.health.value < 100)
          _ActionTile(
            icon: Icons.wifi,
            title: 'Check Wi-Fi Connection',
            subtitle: _getHealthActionSubtitle(currentScore.health),
            color: Colors.green,
            onTap: () => _showHealthTips(context),
          ),
        // Reliability actions
        if (currentScore.reliability.value < 100)
          _ActionTile(
            icon: Icons.monitor_heart,
            title: 'Monitor Servers',
            subtitle: _getReliabilityActionSubtitle(currentScore.reliability),
            color: colors.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ServerCheckerPage()),
            ),
          ),
        // Speed actions
        if (currentScore.speed.value < 100)
          _ActionTile(
            icon: Icons.speed,
            title: 'Test Internet Speed',
            subtitle: currentScore.speed.value < 30
                ? 'Run a speed test to measure your connection'
                : 'Improve download/upload performance',
            color: Colors.amber,
            onTap: () => _runSpeedTest(context),
          ),
        // Vulnerabilities actions
        if (currentScore.vulnerabilities.value < 100)
          _ActionTile(
            icon: Icons.security,
            title: 'Review Security',
            subtitle: 'Address vulnerabilities to improve score',
            color: colors.error,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HostScanPage()),
            ),
          ),
      ],
    );
  }

  String _getHealthActionSubtitle(DimensionScore health) {
    final factors = health.factors;
    if (factors.any((f) => f.contains('No internet connection'))) {
      return 'Check your internet connection';
    }
    if (factors.any((f) => f.contains('Weak Wi-Fi signal'))) {
      return 'Move closer to router or reduce obstacles';
    }
    if (factors.any((f) => f.contains('No gateway'))) {
      return 'Check router connection';
    }
    if (factors.any((f) => f.contains('High latency'))) {
      return 'Reduce network congestion';
    }
    return 'Optimize your network connection';
  }

  String _getReliabilityActionSubtitle(DimensionScore reliability) {
    final factors = reliability.factors;
    if (factors.any((f) => f.contains('No monitors configured'))) {
      return 'Add monitors to track network uptime';
    }
    if (factors.any((f) => f.contains('Missing:'))) {
      return 'Add required monitors for full score';
    }
    if (factors.any((f) => f.contains('High average latency'))) {
      return 'Improve server response times';
    }
    return 'Track reliability of important services';
  }

  void _showHealthTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wi-Fi Health Tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Move closer to your router'),
            Text('• Reduce physical obstacles'),
            Text('• Avoid interference from other devices'),
            Text('• Check for network congestion'),
            Text('• Restart your router if needed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSpeedTest(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SpeedTestPage(),
      ),
    );
    if (mounted) {
      context.read<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
    }
  }

  void _refreshScore(BuildContext context) {
    context.read<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
  }

  Widget _buildStalenessWarning(
    BuildContext context,
    NetworkScore score,
    ColorScheme colors,
  ) {
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
                  'Score reduced due to age',
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
                    'Last fresh score: ${DateFormat('MMM d, h:mm a').format(lastComputedTime)}',
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

  String _getScoreLevelText(ScoreLevel level) {
    switch (level) {
      case ScoreLevel.good:
        return 'Good';
      case ScoreLevel.moderate:
        return 'Moderate';
      case ScoreLevel.poor:
        return 'Needs Attention';
      case ScoreLevel.unknown:
        return 'Unknown';
    }
  }

  String _getScoreDescription(ScoreLevel level) {
    switch (level) {
      case ScoreLevel.good:
        return 'Your network is performing well across all dimensions.';
      case ScoreLevel.moderate:
        return 'Some areas of your network could use improvement.';
      case ScoreLevel.poor:
        return 'Your network has issues that should be addressed.';
      case ScoreLevel.unknown:
        return 'Run network tools to get your score.';
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
                'out of 100',
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
