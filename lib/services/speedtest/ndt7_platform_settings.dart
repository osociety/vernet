import 'dart:io';

/// Per-platform NDT7 test settings.
///
/// Mobile radios (cellular, hotspot) ramp up TCP more slowly and deliver
/// noisier server measurement samples than desktop connections, so each
/// platform gets its own warm-up window and minimum delta-sample window.
/// The active profile also selects the measurement strategy: see
/// [Ndt7StrategyFactory] implementations in the speedtest service package.
class Ndt7PlatformSettings {
  const Ndt7PlatformSettings({
    required this.isMobile,
    required this.warmupDuration,
    required this.downloadTestDuration,
    required this.uploadTestDuration,
    required this.minSampleWindowUs,
    required this.connectionTimeout,
  });

  /// Android and iOS use the mobile profile; everything else desktop.
  factory Ndt7PlatformSettings.resolve() {
    if (Platform.isAndroid || Platform.isIOS) return mobile;
    return desktop;
  }

  /// Android / iOS profile: longer warm-up for radio ramp-up, wider sample
  /// window to smooth bursty TCPInfo delivery.
  static const Ndt7PlatformSettings mobile = Ndt7PlatformSettings(
    isMobile: true,
    warmupDuration: Duration(seconds: 2),
    downloadTestDuration: Duration(seconds: 10),
    uploadTestDuration: Duration(seconds: 10),
    minSampleWindowUs: 100000,
    connectionTimeout: Duration(seconds: 15),
  );

  /// macOS / Windows / Linux profile: short warm-up for fast links, tighter
  /// sample window for more responsive readings.
  static const Ndt7PlatformSettings desktop = Ndt7PlatformSettings(
    isMobile: false,
    warmupDuration: Duration(seconds: 1),
    downloadTestDuration: Duration(seconds: 10),
    uploadTestDuration: Duration(seconds: 10),
    minSampleWindowUs: 25000,
    connectionTimeout: Duration(seconds: 15),
  );

  final bool isMobile;

  /// Initial period excluded from throughput measurement so TCP slow-start
  /// does not drag the result down.
  final Duration warmupDuration;

  final Duration downloadTestDuration;
  final Duration uploadTestDuration;

  /// Minimum elapsed microseconds between anchor and current TCPInfo sample
  /// before an instantaneous throughput value is emitted. Shorter windows
  /// are accumulated into the next one.
  final int minSampleWindowUs;

  final Duration connectionTimeout;
}
