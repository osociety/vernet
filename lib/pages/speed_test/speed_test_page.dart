import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/pages/speed_test/bloc/speed_test_bloc.dart';

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key, this.preloadedServers});

  final List<Ndt7Server>? preloadedServers;

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  late final SpeedTestBloc _bloc;
  bool _initialized = false;
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<SpeedTestBloc>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _bloc.add(SpeedTestEvent.init(preloadedServers: widget.preloadedServers));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    // Don't close the singleton BLoC
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SpeedTestBloc>.value(
      value: _bloc,
      child: BlocListener<SpeedTestBloc, SpeedTestState>(
        listener: (context, state) {
          // Auto-start test once servers are loaded and test hasn't started yet
          if (!_autoStarted &&
              !state.isLoading &&
              state.bestServers != null &&
              state.bestServers!.isNotEmpty &&
              !state.speedTestStarted &&
              !state.downloadSpeedTestDone &&
              !state.uploadSpeedTestDone) {
            _autoStarted = true;
            _bloc.add(const SpeedTestEvent.startTest());
          }
        },
        child: const _SpeedTestView(),
      ),
    );
  }
}

class _SpeedTestView extends StatelessWidget {
  const _SpeedTestView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpeedTestBloc, SpeedTestState>(
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;

        if (state.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Speed Test'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state.fetchError != null &&
            !state.speedTestStarted &&
            state.bestServers == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Speed Test'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Speed Test Unavailable',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.fetchError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Speed Test'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final horizontalPadding = isWide ? 32.0 : 16.0;
              final verticalPadding = isWide ? 24.0 : 16.0;
              final graphHeight = isWide ? 300.0 : 200.0;
              final spacing = isWide ? 24.0 : 16.0;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.speedTestStarted ||
                              (!state.downloadSpeedTestDone &&
                                  !state.uploadSpeedTestDone))
                            _buildSpeedGraph(context, state,
                                colors: colors, height: graphHeight),
                          if (state.speedTestStarted ||
                              (!state.downloadSpeedTestDone &&
                                  !state.uploadSpeedTestDone))
                            SizedBox(height: spacing),
                          if (state.speedTestStarted ||
                              (!state.downloadSpeedTestDone &&
                                  !state.uploadSpeedTestDone))
                            _buildResults(context, state,
                                colors: colors, isWide: isWide),
                          if (state.downloadSpeedTestDone &&
                              state.uploadSpeedTestDone &&
                              !state.speedTestStarted) ...[
                            SizedBox(height: spacing),
                            _buildSummary(context, state,
                                colors: colors, isWide: isWide),
                          ],
                          SizedBox(height: spacing),
                          _buildServerInfo(context, state,
                              colors: colors, isWide: isWide),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: horizontalPadding / 2,
                    ),
                    child: _buildActionButton(context, state, colors: colors),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _showMlabAttributionDialog(context),
                          child: Text(
                            'Powered by Measurement Lab (M-Lab)',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.onSurface.withValues(alpha: 0.6),
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap for terms & privacy info',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.4),
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildServerInfo(BuildContext context, SpeedTestState state,
      {required ColorScheme colors, required bool isWide}) {
    final hasServers = state.bestServers != null && state.bestServers!.isNotEmpty;

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              context
                  .read<SpeedTestBloc>()
                  .add(const SpeedTestEvent.toggleServerInfo());
            },
            child: Padding(
              padding: EdgeInsets.all(isWide ? 20.0 : 16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.dns,
                    color: colors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Server',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasServers
                              ? state.bestServers!.first.displayName
                              : 'No servers available',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    colors.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    state.isServerInfoExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 20.0 : 16.0,
              ).copyWith(bottom: isWide ? 20.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (state.serverLocation != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Server: ${state.serverLocation}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  if (state.packetLossPercent != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.signal_wifi_off,
                          size: 16,
                          color: state.packetLossPercent! > 5
                              ? colors.error
                              : colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Packet Loss: ${state.packetLossPercent!.toStringAsFixed(2)}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: state.isServerInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGraph(BuildContext context, SpeedTestState state,
      {required ColorScheme colors, required double height}) {
    final hasData =
        state.downloadSpeeds.isNotEmpty || state.uploadSpeeds.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Speed Over Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (state.speedTestStarted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${(state.downloadSpeedTestDone && !state.uploadSpeedTestDone ? state.currentUploadSpeed : state.currentDownloadSpeed).toStringAsFixed(1)} Mbps',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: hasData
                  ? LineChart(
                      _createChartData(context, state, colors),
                      duration: const Duration(milliseconds: 250),
                    )
                  : Center(
                      child: Text(
                        'Start the test to see speed graph',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                      ),
                    ),
            ),
            if (hasData) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                    context,
                    colors,
                    const Color(0xFF43EA6A),
                    'Download',
                  ),
                  const SizedBox(width: 24),
                  _buildLegendItem(
                    context,
                    colors,
                    const Color(0xFFFFD700),
                    'Upload',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  LineChartData _createChartData(
      BuildContext context, SpeedTestState state, ColorScheme colors) {
    final allSpeeds = [...state.downloadSpeeds, ...state.uploadSpeeds];
    final rawMax = allSpeeds.isEmpty ? 100.0 : allSpeeds.reduce(max);
    // Round up to nearest 25 for clean Y-axis labels
    final maxY = (rawMax * 1.2).clamp(10.0, double.infinity);
    final roundedMaxY = (maxY / 25).ceil() * 25.0;

    return LineChartData(
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: roundedMaxY / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colors.onSurface.withValues(alpha: 0.1),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          
        ),
        topTitles: const AxisTitles(
          
        ),
        bottomTitles: const AxisTitles(
          
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: roundedMaxY / 4,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.round()} Mbps',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      minX: 0,
      maxX: ((state.downloadSpeeds.length > state.uploadSpeeds.length
                  ? state.downloadSpeeds.length
                  : state.uploadSpeeds.length) -
              1)
          .toDouble()
          .clamp(0.0, double.infinity) +
          0.5, // Add small buffer to prevent line from extending beyond chart
      minY: 0,
      maxY: roundedMaxY,
      lineBarsData: [
        if (state.downloadSpeeds.isNotEmpty)
          _createLineChartBar(
            state.downloadSpeeds,
            const Color(0xFF43EA6A),
            state.uploadSpeeds.length,
          ),
        if (state.uploadSpeeds.isNotEmpty)
          _createLineChartBar(
            state.uploadSpeeds,
            const Color(0xFFFFD700),
            state.downloadSpeeds.length,
          ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final color = spot.barIndex == 0
                  ? const Color(0xFF43EA6A)
                  : const Color(0xFFFFD700);
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} Mbps',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  LineChartBarData _createLineChartBar(List<double> speeds, Color color, int otherLength) {
    final paddedSpeeds = List<double>.from(speeds);
    // Pad with last value to match the other dataset's length
    if (paddedSpeeds.length < otherLength && paddedSpeeds.isNotEmpty) {
      final lastValue = paddedSpeeds.last;
      while (paddedSpeeds.length < otherLength) {
        paddedSpeeds.add(lastValue);
      }
    }
    
    return LineChartBarData(
      spots: List.generate(
        paddedSpeeds.length,
        (i) => FlSpot(i.toDouble(), paddedSpeeds[i]),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildLegendItem(
      BuildContext context, ColorScheme colors, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, SpeedTestState state,
      {required ColorScheme colors, required bool isWide}) {
    return Row(
      children: [
        Expanded(
          child: _buildResultCard(
            context,
            colors,
            Icons.download,
            'Download',
            state.downloadSpeedTestDone ? state.currentDownloadSpeed : null,
            const Color(0xFF43EA6A),
            isWide: isWide,
          ),
        ),
        SizedBox(width: isWide ? 12 : 8),
        Expanded(
          child: _buildResultCard(
            context,
            colors,
            Icons.upload,
            'Upload',
            state.uploadSpeedTestDone ? state.currentUploadSpeed : null,
            const Color(0xFFFFD700),
            isWide: isWide,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    ColorScheme colors,
    IconData icon,
    String label,
    double? value,
    Color color, {
    required bool isWide,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 16.0 : 12.0,
          vertical: isWide ? 16.0 : 12.0,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isWide ? 32 : 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value != null ? '${value.toStringAsFixed(1)} Mbps' : '--',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, SpeedTestState state,
      {required ColorScheme colors, required bool isWide}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: colors.primary,
              size: isWide ? 64 : 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Test Complete',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    colors,
                    Icons.download,
                    'Download',
                    state.currentDownloadSpeed,
                    const Color(0xFF43EA6A),
                    isWide: isWide,
                  ),
                ),
                SizedBox(width: isWide ? 24 : 16),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    colors,
                    Icons.upload,
                    'Upload',
                    state.currentUploadSpeed,
                    const Color(0xFFFFD700),
                    isWide: isWide,
                  ),
                ),
                if (isWide) ...[
                  SizedBox(width: isWide ? 24 : 16),
                  Expanded(
                    child: _buildSummaryItem(
                      context,
                      colors,
                      Icons.network_ping,
                      'Latency',
                      state.latencyMs ?? 0,
                      colors.primary,
                      isWide: isWide,
                      unit: 'ms',
                    ),
                  ),
                ],
              ],
            ),
            if (!isWide) ...[
              const SizedBox(height: 16),
              _buildSummaryItem(
                context,
                colors,
                Icons.network_ping,
                'Latency',
                state.latencyMs ?? 0,
                colors.primary,
                isWide: isWide,
                unit: 'ms',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    ColorScheme colors,
    IconData icon,
    String label,
    double value,
    Color color, {
    required bool isWide,
    String unit = 'Mbps',
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: isWide ? 32 : 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, SpeedTestState state, {required ColorScheme colors}) {
    final hasServers = state.bestServers != null && state.bestServers!.isNotEmpty;
    final isTestComplete = state.downloadSpeedTestDone && state.uploadSpeedTestDone && !state.speedTestStarted;

    // Only show button after test completes (for "Test Again")
    if (!isTestComplete) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasServers
            ? () {
                context
                    .read<SpeedTestBloc>()
                    .add(const SpeedTestEvent.startTest());
              }
            : null,
        icon: const Icon(Icons.refresh),
        label: const Text('Test Again'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
      ),
    );
  }

  void _showMlabAttributionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Measurement Lab (M-Lab)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Speed tests are powered by M-Lab's NDT7 protocol, providing accurate and standardized internet measurements.",
              ),
              const SizedBox(height: 16),
              Text(
                'About M-Lab',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Measurement Lab (M-Lab) is a research initiative that provides open internet measurement data. Learn more about their mission and data practices.',
              ),
              const SizedBox(height: 16),
              _buildLinkTile(
                context,
                icon: Icons.language,
                title: 'M-Lab Website',
                subtitle: 'www.measurementlab.net',
                url: 'https://www.measurementlab.net/',
              ),
              _buildLinkTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How M-Lab handles your data',
                url: 'https://www.measurementlab.net/privacy-policy/',
              ),
              _buildLinkTile(
                context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Usage terms and conditions',
                url: 'https://www.measurementlab.net/terms-of-service/',
              ),
              _buildLinkTile(
                context,
                icon: Icons.info_outline,
                title: 'About NDT Test',
                subtitle: 'Technical documentation',
                url: 'https://www.measurementlab.net/tests/ndt/',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => launchURLWithWarning(context, url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
