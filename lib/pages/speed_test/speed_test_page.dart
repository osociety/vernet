import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/repository/network_score_repository.dart';

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key, this.preloadedServers});

  final List<Server>? preloadedServers;

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  final SpeedTestDart _tester = SpeedTestDart();
  final rng = Random();
  static const int numberOfTests = 2;

  List<Server>? _bestServers;
  IspInfo? _ispInfo;
  String? _fetchError;
  bool _isLoading = true;
  bool _speedTestStarted = false;
  bool _downloadSpeedTestDone = false;
  bool _uploadSpeedTestDone = false;
  bool _isServerInfoExpanded = false;

  double _currentDownloadSpeed = 0;
  double _currentUploadSpeed = 0;
  Timer? _timer;

  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<double> _latencies = [];

  @override
  void initState() {
    super.initState();
    _loadIspInfo();
    if (widget.preloadedServers != null && widget.preloadedServers!.isNotEmpty) {
      setState(() {
        _bestServers = widget.preloadedServers;
        _isLoading = false;
      });
    } else {
      _getBestServers();
    }
  }

  Future<void> _loadIspInfo() async {
    final ispInfo = await NetworkScoreRepository().loadIspInfo();
    if (mounted) {
      setState(() {
        _ispInfo = ispInfo;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getBestServers() async {
    try {
      // First get settings which includes available servers
      final settings = await _tester.getSettings(headers: {"User-Agent": "Mozilla/4.0"});
      
      // Then get the best servers from the available list
      final result = await _tester.getBestServers(servers: settings.servers);
      result.sort((a, b) => a.latency.compareTo(b.latency));
      
      if (mounted) {
        setState(() {
          _bestServers = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = 'Could not find test servers. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startSpeedTest() async {
    if (_bestServers == null || _bestServers!.isEmpty) {
      return;
    }

    setState(() {
      _speedTestStarted = true;
      _downloadSpeedTestDone = false;
      _uploadSpeedTestDone = false;
      _downloadSpeeds.clear();
      _uploadSpeeds.clear();
      _latencies.clear();
    });

    try {
      await _testDownloadSpeed();
      await _testUploadSpeed();
      await _saveSpeedSnapshot();
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = 'Speed test failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _speedTestStarted = false;
          _isServerInfoExpanded = true;
        });
      }
    }
  }

  Future<void> _testDownloadSpeed() async {
    if (_bestServers == null || _bestServers!.isEmpty) return;

    _currentDownloadSpeed = 0;
    _timer?.cancel();
    _downloadSpeeds.clear();

    // Add initial fake point
    if (mounted) {
      setState(() {
        _downloadSpeeds.add(0);
      });
    }

    // Timer to add fake points during the test to show progress
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (Timer t) {
        if (mounted) {
          setState(() {
            // Simulate speed variation
            _currentDownloadSpeed = _currentDownloadSpeed +
                (Random().nextDouble() * 10 - 3);
            if (_currentDownloadSpeed < 0) _currentDownloadSpeed = 0;
            if (_currentDownloadSpeed > 100) _currentDownloadSpeed = 100;
            
            // Add fake point to show progress
            _downloadSpeeds.add(_currentDownloadSpeed);
          });
        }
      },
    );

    for (int i = 0; i < numberOfTests; i++) {
      final speed = await _tester.testDownloadSpeed(servers: _bestServers!);
      if (mounted) {
        setState(() {
          _currentDownloadSpeed = speed;
          // Clear fake points and add only real results
          _downloadSpeeds.clear();
          _downloadSpeeds.add(speed);
        });
      }
    }

    _timer?.cancel();
    if (mounted) {
      setState(() {
        _downloadSpeedTestDone = true;
      });
    }
  }

  Future<void> _testUploadSpeed() async {
    if (_bestServers == null || _bestServers!.isEmpty) return;

    _currentUploadSpeed = 0;
    _timer?.cancel();
    _uploadSpeeds.clear();
    _downloadSpeeds.clear(); // Clear download speeds to avoid scaling issues

    // Add initial fake point
    if (mounted) {
      setState(() {
        _uploadSpeeds.add(0);
      });
    }

    // Timer to add fake points during the test to show progress
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (Timer t) {
        if (mounted) {
          setState(() {
            // Simulate small speed variation (±2 Mbps)
            _currentUploadSpeed = _currentUploadSpeed +
                (Random().nextDouble() * 4 - 2);
            if (_currentUploadSpeed < 0) _currentUploadSpeed = 0;
            if (_currentUploadSpeed > 100) _currentUploadSpeed = 100;
            
            // Add fake point to show progress
            _uploadSpeeds.add(_currentUploadSpeed);
          });
        }
      },
    );

    for (int i = 0; i < numberOfTests; i++) {
      final speed = await _tester.testUploadSpeed(servers: _bestServers!);
      if (mounted) {
        setState(() {
          _currentUploadSpeed = speed;
          // Clear fake points and add only real results
          _uploadSpeeds.clear();
          _uploadSpeeds.add(speed);
        });
      }
    }

    _timer?.cancel();
    if (mounted) {
      setState(() {
        _uploadSpeedTestDone = true;
      });
    }
  }

  Future<void> _saveSpeedSnapshot() async {
    if (_bestServers == null || _bestServers!.isEmpty) return;

    final ispInfo = await NetworkScoreRepository().loadIspInfo();
    await NetworkScoreRepository().saveSpeedSnapshot(SpeedSnapshot(
      downloadMbps: _currentDownloadSpeed,
      uploadMbps: _currentUploadSpeed,
      latencyMs: _bestServers!.first.latency.toDouble(),
      ispRating: ispInfo?.ispRating,
      ispAvgDownloadMbps: ispInfo?.avgDownloadMbps,
      ispAvgUploadMbps: ispInfo?.avgUploadMbps,
      ispName: ispInfo?.ispName,
    ));

    // Trigger score recomputation with fresh speed data
    if (mounted) {
      getIt<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Speed Test'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_fetchError != null) {
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
                  _fetchError!,
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
                      if (_speedTestStarted || (!_downloadSpeedTestDone && !_uploadSpeedTestDone))
                        _buildSpeedGraph(colors, height: graphHeight),
                      if (_speedTestStarted || (!_downloadSpeedTestDone && !_uploadSpeedTestDone))
                        SizedBox(height: spacing),
                      if (_speedTestStarted || (!_downloadSpeedTestDone && !_uploadSpeedTestDone))
                        _buildResults(colors, isWide: isWide),
                      if (_downloadSpeedTestDone && _uploadSpeedTestDone && !_speedTestStarted) ...[
                        SizedBox(height: spacing),
                        _buildSummary(colors, isWide: isWide),
                      ],
                      SizedBox(height: spacing),
                      _buildServerInfo(colors, isWide: isWide),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: horizontalPadding / 2,
                ),
                child: _buildActionButton(colors),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: horizontalPadding,
                ),
                child: Text(
                  'Powered by Speedtest by Ookla®',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServerInfo(ColorScheme colors, {required bool isWide}) {
    final hasServers = _bestServers != null && _bestServers!.isNotEmpty;
    
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isServerInfoExpanded = !_isServerInfoExpanded;
              });
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasServers ? _bestServers!.first.name : 'No servers available',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isServerInfoExpanded ? Icons.expand_less : Icons.expand_more,
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
                  if (hasServers)
                    Row(
                      children: [
                        Icon(
                          Icons.network_ping,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Latency: ${_bestServers!.first.latency} ms',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  if (_ispInfo?.ispName != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Internet Provider',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ispInfo!.ispName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (_ispInfo!.ispRating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rating: ${_ispInfo!.ispRating!.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            crossFadeState: _isServerInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGraph(ColorScheme colors, {required double height}) {
    final hasData = _downloadSpeeds.isNotEmpty || _uploadSpeeds.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speed Over Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: hasData
                  ? LineChart(
                      _createChartData(colors),
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
                    colors,
                    const Color(0xFF43EA6A),
                    'Download',
                  ),
                  const SizedBox(width: 24),
                  _buildLegendItem(
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

  LineChartData _createChartData(ColorScheme colors) {
    final allSpeeds = [..._downloadSpeeds, ..._uploadSpeeds];
    final maxY = allSpeeds.isEmpty
        ? 100.0
        : (allSpeeds.reduce(max) * 1.2).clamp(10.0, double.infinity);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colors.onSurface.withValues(alpha: 0.1),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: maxY / 4,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
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
      maxX: ((_downloadSpeeds.length > _uploadSpeeds.length
                  ? _downloadSpeeds.length
                  : _uploadSpeeds.length) -
              1)
          .toDouble()
          .clamp(0.0, double.infinity) + 1,
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        if (_downloadSpeeds.isNotEmpty)
          _createLineChartBar(
            _downloadSpeeds,
            const Color(0xFF43EA6A),
          ),
        if (_uploadSpeeds.isNotEmpty)
          _createLineChartBar(
            _uploadSpeeds,
            const Color(0xFFFFD700),
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

  LineChartBarData _createLineChartBar(List<double> speeds, Color color) {
    return LineChartBarData(
      spots: List.generate(
        speeds.length,
        (i) => FlSpot(i.toDouble(), speeds[i]),
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

  Widget _buildLegendItem(ColorScheme colors, Color color, String label) {
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

  Widget _buildResults(ColorScheme colors, {required bool isWide}) {
    return Row(
      children: [
        Expanded(
          child: _buildResultCard(
            colors,
            Icons.download,
            'Download',
            _downloadSpeedTestDone ? _currentDownloadSpeed : null,
            const Color(0xFF43EA6A),
            isWide: isWide,
          ),
        ),
        SizedBox(width: isWide ? 12 : 8),
        Expanded(
          child: _buildResultCard(
            colors,
            Icons.upload,
            'Upload',
            _uploadSpeedTestDone ? _currentUploadSpeed : null,
            const Color(0xFFFFD700),
            isWide: isWide,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(
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

  Widget _buildSummary(ColorScheme colors, {required bool isWide}) {
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
                    colors,
                    Icons.download,
                    'Download',
                    _currentDownloadSpeed,
                    const Color(0xFF43EA6A),
                    isWide: isWide,
                  ),
                ),
                SizedBox(width: isWide ? 24 : 16),
                Expanded(
                  child: _buildSummaryItem(
                    colors,
                    Icons.upload,
                    'Upload',
                    _currentUploadSpeed,
                    const Color(0xFFFFD700),
                    isWide: isWide,
                  ),
                ),
                if (isWide) ...[
                  SizedBox(width: isWide ? 24 : 16),
                  Expanded(
                    child: _buildSummaryItem(
                      colors,
                      Icons.network_ping,
                      'Latency',
                      _bestServers?.first.latency.toDouble() ?? 0,
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
                colors,
                Icons.network_ping,
                'Latency',
                _bestServers?.first.latency.toDouble() ?? 0,
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

  Widget _buildActionButton(ColorScheme colors) {
    final hasServers = _bestServers != null && _bestServers!.isNotEmpty;
    final canStart = !_speedTestStarted && hasServers;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canStart ? _startSpeedTest : null,
        icon: _speedTestStarted
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(
          _speedTestStarted
              ? 'Testing...'
              : !hasServers
                  ? 'No Servers Available'
                  : _downloadSpeedTestDone && _uploadSpeedTestDone
                      ? 'Test Again'
                      : 'Start Test',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
      ),
    );
  }
}
