import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/timestamp_chip.dart';

class NetworkScoreCard extends StatelessWidget {
  const NetworkScoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkScoreBloc, NetworkScoreState>(
      builder: (context, state) {
        return state.when(
          initial: () => _buildInitialCard(context),
          computing: () => _buildComputingCard(context),
          success: (score) => _buildScoreCard(context, score),
          failure: (message) => _buildErrorCard(context, message),
        );
      },
    );
  }

  Widget _buildInitialCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ScoreCardContainer(
      onTap: () => _triggerCompute(context),
      child: Column(
        children: [
          Row(
            children: [
              _ScoreIcon(icon: Icons.speed, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NETWORK SCORE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to assess your network',
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
        ],
      ),
    );
  }

  Widget _buildComputingCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ScoreCardContainer(
      child: Row(
        children: [
          _ScoreIcon(icon: Icons.analytics, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NETWORK SCORE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Computing your network score...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child: AdaptiveCircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, NetworkScore score) {
    final colors = Theme.of(context).colorScheme;
    final scoreColor = _getScoreColor(score.overallScore, colors);
    final hasStalenessDecay = score.metadata['stalenessDecay'] != null;

    return _ScoreCardContainer(
      onTap: () => _openDetailPage(context, score),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreIcon(icon: Icons.speed, color: scoreColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'NETWORK SCORE',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        TimestampChip(timestamp: score.computedAt),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScoreDescription(score.level),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    if (hasStalenessDecay) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Score reduced due to age',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.tertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _OverallScoreBadge(score: score.overallScore, color: scoreColor),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          _DimensionBars(dimensions: score.dimensions),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return _ScoreCardContainer(
      onTap: () => _triggerCompute(context),
      child: Row(
        children: [
          _ScoreIcon(icon: Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NETWORK SCORE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unable to compute score. Tap to retry.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                ),
              ],
            ),
          ),
          Icon(Icons.refresh, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }

  void _triggerCompute(BuildContext context) {
    context.read<NetworkScoreBloc>().add(const NetworkScoreEvent.compute());
  }

  void _openDetailPage(BuildContext context, NetworkScore score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkScoreDetailPage(initialScore: score),
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

  String _getScoreDescription(ScoreLevel level) {
    switch (level) {
      case ScoreLevel.good:
        return 'Your network is in good shape';
      case ScoreLevel.moderate:
        return 'Some areas need attention';
      case ScoreLevel.poor:
        return 'Network issues detected';
      case ScoreLevel.unknown:
        return 'Score not yet computed';
    }
  }
}

class _ScoreCardContainer extends StatelessWidget {
  const _ScoreCardContainer({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant.withAlpha(120)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ScoreIcon extends StatelessWidget {
  const _ScoreIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _OverallScoreBadge extends StatelessWidget {
  const _OverallScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(width: 2),
          Text(
            '/100',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withAlpha(180),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DimensionBars extends StatefulWidget {
  const _DimensionBars({required this.dimensions});

  final List<DimensionScore> dimensions;

  @override
  State<_DimensionBars> createState() => _DimensionBarsState();
}

class _DimensionBarsState extends State<_DimensionBars> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(widget.dimensions.length, (index) {
        final dim = widget.dimensions[index];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = index),
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: Column(
                children: [
                  _DimensionBar(
                    value: dim.value,
                    color: _getDimensionColor(dim.level, colors),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getDimensionLabel(dim.name),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      height: _hoveredIndex == index ? 16 : 0,
                      child: Text(
                        '${dim.value}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getDimensionColor(dim.level, colors),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getDimensionColor(ScoreLevel level, ColorScheme colors) {
    switch (level) {
      case ScoreLevel.good:
        return colors.primary;
      case ScoreLevel.moderate:
        return Colors.amber;
      case ScoreLevel.poor:
        return colors.error;
      case ScoreLevel.unknown:
        return colors.outlineVariant;
    }
  }

  String _getDimensionLabel(String name) {
    switch (name) {
      case 'Security':
        return 'SEC';
      case 'Health':
        return 'HLT';
      case 'Reliability':
        return 'REL';
      case 'Speed':
        return 'SPD';
      case 'Vulnerabilities':
        return 'VUL';
      default:
        return name.substring(0, name.length.clamp(0, 3)).toUpperCase();
    }
  }
}

class _DimensionBar extends StatelessWidget {
  const _DimensionBar({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
