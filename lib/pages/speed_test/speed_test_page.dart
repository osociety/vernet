import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/pages/speed_test/bloc/speed_test_bloc.dart';

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key, this.preloadedServers, this.preloadedResult});

  final List<Ndt7Server>? preloadedServers;
  final Ndt7TestResult? preloadedResult;

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  late final SpeedTestBloc _bloc;
  bool _initialized = false;
  bool _consentGiven = false;
  String? _lastShownError;

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
      if (widget.preloadedResult != null) {
        _bloc.add(SpeedTestEvent.loadResult(result: widget.preloadedResult!));
      }
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
          // Show error message only when it changes
          if (state.fetchError != null &&
              state.fetchError != _lastShownError &&
              !state.speedTestStarted) {
            _lastShownError = state.fetchError;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.fetchError!),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: _SpeedTestView(
          consentGiven: _consentGiven,
          onConsentChanged: (value) {
            setState(() {
              _consentGiven = value;
            });
          },
        ),
      ),
    );
  }
}

class _SpeedTestView extends StatelessWidget {
  const _SpeedTestView({
    required this.consentGiven,
    required this.onConsentChanged,
  });

  final bool consentGiven;
  final ValueChanged<bool> onConsentChanged;

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

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Show graph (empty before test, with data during test)
                  if (!state.showSummary)
                    _buildSpeedGraph(context, state,
                        colors: colors, height: graphHeight),
                  if (!state.showSummary) SizedBox(height: spacing),
                  if (!state.showSummary)
                    _buildResults(context, state,
                        colors: colors, isWide: isWide),
                  if (state.showSummary)
                    _buildSummary(context, state,
                        colors: colors, isWide: isWide),
                  SizedBox(height: spacing),
                  _buildServerInfo(context, state,
                      colors: colors, isWide: isWide),
                ],
              );

              final bottomSections = <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: horizontalPadding / 2,
                  ),
                  child: Column(
                    children: [
                      // Data policy consent checkbox (shown before test starts)
                      if (!state.speedTestStarted &&
                          !state.downloadSpeedTestDone &&
                          !state.uploadSpeedTestDone &&
                          !state.showSummary)
                        _buildConsentCard(context, colors, isWide: isWide),
                      if (!state.speedTestStarted &&
                          !state.downloadSpeedTestDone &&
                          !state.uploadSpeedTestDone &&
                          !state.showSummary)
                        const SizedBox(height: 12),
                      _buildActionButton(context, state, colors: colors),
                    ],
                  ),
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
              ];

              // Short viewports (landscape phones) have no room for both a
              // pinned action area and a usable content viewport, so the whole
              // page scrolls instead of overflowing.
              if (constraints.maxHeight < 400) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: content,
                      ),
                      ...bottomSections,
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: content,
                    ),
                  ),
                  ...bottomSections,
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
    final hasServers =
        state.bestServers != null && state.bestServers!.isNotEmpty;

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
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                color: colors.onSurface.withValues(alpha: 0.7),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
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
    // Calculate Y-axis max based on active test only
    final activeSpeeds = _getActiveSpeeds(state);
    final rawMax = activeSpeeds.isEmpty ? 100.0 : activeSpeeds.reduce(max);
    // Round up to nearest 25 for clean Y-axis labels
    final maxY = (rawMax * 1.2).clamp(10.0, double.infinity);
    final roundedMaxY = (maxY / 25).ceil() * 25.0;

    return LineChartData(
      clipData: const FlClipData.all(),
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
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: const AxisTitles(),
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
      maxX: _getActiveDataLength(state).toDouble().clamp(0.0, double.infinity) +
          2.0,
      minY: 0,
      maxY: roundedMaxY,
      lineBarsData: [
        // Show download graph only when download is running (upload not started)
        if (state.downloadSpeeds.isNotEmpty && !state.downloadSpeedTestDone)
          _createLineChartBar(
            state.downloadSpeeds,
            const Color(0xFF43EA6A),
            0,
          ),
        // Show upload graph only when upload is running (download is done)
        if (state.uploadSpeeds.isNotEmpty &&
            state.downloadSpeedTestDone &&
            !state.uploadSpeedTestDone)
          _createLineChartBar(
            state.uploadSpeeds,
            const Color(0xFFFFD700),
            0,
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

  int _getActiveDataLength(SpeedTestState state) {
    // Show upload length when upload is running (download is done)
    if (state.downloadSpeedTestDone &&
        !state.uploadSpeedTestDone &&
        state.uploadSpeeds.isNotEmpty) {
      return state.uploadSpeeds.length;
    }
    // Show download length when download is running
    if (!state.downloadSpeedTestDone && state.downloadSpeeds.isNotEmpty) {
      return state.downloadSpeeds.length;
    }
    // Fallback to the longer dataset
    return state.downloadSpeeds.length > state.uploadSpeeds.length
        ? state.downloadSpeeds.length
        : state.uploadSpeeds.length;
  }

  List<double> _getActiveSpeeds(SpeedTestState state) {
    // Show upload speeds when upload is running (download is done)
    if (state.downloadSpeedTestDone &&
        !state.uploadSpeedTestDone &&
        state.uploadSpeeds.isNotEmpty) {
      return state.uploadSpeeds;
    }
    // Show download speeds when download is running
    if (!state.downloadSpeedTestDone && state.downloadSpeeds.isNotEmpty) {
      return state.downloadSpeeds;
    }
    // Fallback to all speeds
    return [...state.downloadSpeeds, ...state.uploadSpeeds];
  }

  LineChartBarData _createLineChartBar(
      List<double> speeds, Color color, int otherLength) {
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
            isWarmingUp: state.isWarmingUp && !state.uploadSpeedTestDone,
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
    bool isWarmingUp = false,
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
            if (isWarmingUp)
              Text(
                'Warming up...',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                textAlign: TextAlign.center,
              )
            else
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
    final downloadSpeed = state.currentDownloadSpeed;
    final uploadSpeed = state.currentUploadSpeed;
    final latency = state.latencyMs;
    final retransmission = state.retransmissionPercentage;
    final rating = _getSpeedRating(downloadSpeed);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          // Hero speed card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primaryContainer,
                  colors.primaryContainer.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40.0 : 24.0,
                vertical: isWide ? 32.0 : 28.0,
              ),
              child: Column(
                children: [
                  // Speed rating badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: rating.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(rating.icon, size: 16, color: rating.color),
                        const SizedBox(width: 6),
                        Text(
                          rating.label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: rating.color,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Animated download speed
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: downloadSpeed),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Column(
                      children: [
                        Text(
                          value.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.onPrimaryContainer,
                                height: 1.0,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mbps Download',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Gauge arc
                  CustomPaint(
                    size: Size(isWide ? 280 : 220, isWide ? 140 : 110),
                    painter: _SpeedGaugePainter(
                      progress: (downloadSpeed / 500).clamp(0.0, 1.0),
                      color: colors.primary,
                      strokeWidth: isWide ? 10 : 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Upload card (separate row on mobile, combined on desktop)
          if (!isWide)
            SizedBox(
              width: double.infinity,
              child: _buildMetricCard(
                context,
                colors,
                Icons.upload,
                'Upload',
                uploadSpeed,
                'Mbps',
                const Color(0xFFFFD700),
                isWide: isWide,
                isWarmingUp: state.isWarmingUp && !state.uploadSpeedTestDone,
              ),
            ),
          if (!isWide) const SizedBox(height: 12),
          // Latency & Retransmission row (or all three on desktop)
          IntrinsicHeight(
            child: Row(
              children: [
                if (isWide)
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      colors,
                      Icons.upload,
                      'Upload',
                      uploadSpeed,
                      'Mbps',
                      const Color(0xFFFFD700),
                      isWide: isWide,
                      isWarmingUp:
                          state.isWarmingUp && !state.uploadSpeedTestDone,
                    ),
                  ),
                if (isWide) SizedBox(width: isWide ? 16 : 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    colors,
                    Icons.timer,
                    'Latency',
                    latency,
                    'ms',
                    _getLatencyColor(latency ?? 999, colors),
                    isWide: isWide,
                  ),
                ),
                SizedBox(width: isWide ? 16 : 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    colors,
                    Icons.sync,
                    'Retrans',
                    retransmission,
                    '%',
                    _getRetransmissionColor(retransmission ?? 100, colors),
                    isWide: isWide,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // What you can do
          _buildCapabilities(context, colors, downloadSpeed, isWide: isWide),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    ColorScheme colors,
    IconData icon,
    String label,
    double? value,
    String unit,
    Color color, {
    required bool isWide,
    bool isWarmingUp = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 20.0 : 16.0,
        vertical: isWide ? 20.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 4),
          if (isWarmingUp)
            Text(
              'Warming up...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value ?? 0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                value != null ? '${v.toStringAsFixed(1)} $unit' : '--',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCapabilities(
      BuildContext context, ColorScheme colors, double downloadSpeed,
      {required bool isWide}) {
    final capabilities = _getCapabilities(downloadSpeed);
    if (capabilities.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 20.0 : 16.0),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you can do',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capabilities
                .map((cap) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cap.icon, size: 14, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            cap.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  SpeedRating _getSpeedRating(double speed) {
    if (speed >= 200) {
      return const SpeedRating('Excellent', Icons.bolt, Color(0xFF43EA6A));
    } else if (speed >= 100) {
      return const SpeedRating('Great', Icons.rocket_launch, Color(0xFF43EA6A));
    } else if (speed >= 50) {
      return const SpeedRating('Good', Icons.check_circle, Color(0xFF8BC34A));
    } else if (speed >= 25) {
      return const SpeedRating('Fair', Icons.remove_circle, Color(0xFFFFD700));
    } else if (speed >= 10) {
      return const SpeedRating('Slow', Icons.trending_down, Color(0xFFFF9800));
    } else {
      return const SpeedRating('Very Slow', Icons.warning, Color(0xFFF44336));
    }
  }

  Color _getLatencyColor(double latencyMs, ColorScheme colors) {
    if (latencyMs < 20) return const Color(0xFF43EA6A);
    if (latencyMs < 50) return const Color(0xFF8BC34A);
    if (latencyMs < 100) return const Color(0xFFFFD700);
    return const Color(0xFFF44336);
  }

  Color _getRetransmissionColor(
      double retransmissionPercent, ColorScheme colors) {
    if (retransmissionPercent < 1) return const Color(0xFF43EA6A);
    if (retransmissionPercent < 5) return const Color(0xFFFFD700);
    return const Color(0xFFF44336);
  }

  List<Capability> _getCapabilities(double downloadSpeed) {
    final caps = <Capability>[];
    if (downloadSpeed >= 5)
      caps.add(const Capability(Icons.music_note, 'Music'));
    if (downloadSpeed >= 10)
      caps.add(const Capability(Icons.videocam, 'Video calls'));
    if (downloadSpeed >= 25)
      caps.add(const Capability(Icons.hd, 'HD streaming'));
    if (downloadSpeed >= 50)
      caps.add(const Capability(Icons.sports_esports, 'Gaming'));
    if (downloadSpeed >= 100)
      caps.add(const Capability(Icons.tv, '4K streaming'));
    if (downloadSpeed >= 200)
      caps.add(const Capability(Icons.cloud_upload, 'Fast uploads'));
    return caps;
  }

  Widget _buildConsentCard(BuildContext context, ColorScheme colors,
      {required bool isWide}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 24.0 : 20.0,
        vertical: isWide ? 24.0 : 20.0,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Checkbox(
            value: consentGiven,
            onChanged: (value) {
              onConsentChanged(value ?? false);
            },
            activeColor: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I agree to the data policy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Includes retention and publication of IP addresses',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SpeedTestState state,
      {required ColorScheme colors}) {
    final hasServers =
        state.bestServers != null && state.bestServers!.isNotEmpty;

    // Show "Start Test" button before test begins
    if (!state.speedTestStarted &&
        !state.downloadSpeedTestDone &&
        !state.uploadSpeedTestDone &&
        !state.showSummary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (hasServers && consentGiven)
              ? () {
                  context
                      .read<SpeedTestBloc>()
                      .add(const SpeedTestEvent.startTest());
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Test'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
          ),
        ),
      );
    }

    // Only show "Test Again" button after test completes
    if (!state.showSummary) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasServers
            ? () {
                print('SpeedTestPage: Test Again button pressed');
                print('SpeedTestPage: hasServers=$hasServers');
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
              Icon(icon,
                  size: 24, color: Theme.of(context).colorScheme.primary),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeedRating {
  const SpeedRating(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Capability {
  const Capability(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _SpeedGaugePainter extends CustomPainter {
  _SpeedGaugePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width / 2) - strokeWidth;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_SpeedGaugePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
