import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/services/speedtest/ndt7_desktop_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_mobile_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

Ndt7Measurement _tcpInfo({
  int? bytesSent,
  int? bytesReceived,
  int? elapsedUs,
}) =>
    Ndt7Measurement(
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      elapsedTimeUs: elapsedUs,
    );

Ndt7Measurement _appInfo(double mbps) => Ndt7Measurement(throughputMbps: mbps);

void main() {
  group('DeltaWindowAccumulator', () {
    test('first sample anchors and returns null', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      expect(acc.feed(1000, 0), isNull);
    });

    test('sub-window samples accumulate and return null', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      acc.feed(1000, 0);
      expect(acc.feed(2000, 50000), isNull);
    });

    test('emits instantaneous Mbps once window threshold is reached', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      acc.feed(1000, 0);
      // 3000 bytes over 150000us = 8 * 3000 / 0.15 / 1e6 = 0.16 Mbps
      expect(acc.feed(4000, 150000), closeTo(0.16, 1e-9));
    });

    test('re-anchors after emitting so next window starts fresh', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      acc.feed(1000, 0);
      acc.feed(4000, 150000);
      // Delta of 1000 bytes over 50000us is below the window: the sample is
      // accumulated into the next window, which keeps the old anchor.
      expect(acc.feed(5000, 200000), isNull);
      // 5000 bytes over 200000us from the old anchor = 0.2 Mbps.
      expect(acc.feed(9000, 350000), closeTo(0.2, 1e-9));
    });

    test('non-positive delta time returns null', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      acc.feed(1000, 0);
      expect(acc.feed(4000, 150000), isNotNull);
      expect(acc.feed(5000, 150000), isNull);
    });

    test('reset clears the anchor', () {
      final acc = DeltaWindowAccumulator(minWindowUs: 100000);
      acc.feed(1000, 0);
      acc.reset();
      expect(acc.feed(9000, 500000), isNull);
    });
  });

  group('MobileNdt7Strategy download', () {
    test('uses ClientDeltaTracker (client-side delta median)', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      expect(tracker, isA<ClientDeltaTracker>());
    });

    test('ignores server TCPInfo (client-side only)', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 99999999, elapsedUs: 5000000),
        const Duration(seconds: 5),
      );
      expect(tracker.throughputMbps, isNull,
          reason: 'mobile download uses client-side bytes, not server TCPInfo');
    });

    test('reports median of post-warm-up delta samples', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      // Warm-up is 2s; samples before that anchor the baseline.
      tracker.onClientBytes(1000000, const Duration(seconds: 1));
      tracker.onClientBytes(2000000, const Duration(seconds: 2));
      // Post-warm-up deltas: 1MB over 1s = 8 Mbps, 5MB over 1s = 40 Mbps, 7MB over 1s = 56 Mbps.
      tracker.onClientBytes(3000000, const Duration(seconds: 3));
      tracker.onClientBytes(8000000, const Duration(seconds: 4));
      tracker.onClientBytes(15000000, const Duration(seconds: 5));
      // Median of [8, 40, 56] = 40 Mbps.
      expect(tracker.throughputMbps, closeTo(40.0, 1e-9));
    });
  });

  group('ServerDeltaTracker upload (mobile)', () {
    test('never falls back to client-side byte counting', () {
      final tracker = const MobileNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.mobile);
      tracker.onClientBytes(2000000, const Duration(seconds: 2));
      tracker.onClientBytes(10000000, const Duration(seconds: 4));
      expect(tracker.throughputMbps, isNull,
          reason: 'mobile upload buffers make client counting meaningless');
    });

    test('uses BytesReceived, not BytesSent', () {
      final tracker = const MobileNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.mobile);
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 999999, bytesReceived: 1000000, elapsedUs: 3000000),
        const Duration(seconds: 3),
      );
      // 250000 received bytes over 200000us = 10 Mbps. If BytesSent were used
      // the result would be wildly different.
      tracker.onServerMeasurement(
        _tcpInfo(
            bytesSent: 1999999, bytesReceived: 1250000, elapsedUs: 3200000),
        const Duration(seconds: 3, milliseconds: 200),
      );
      expect(tracker.throughputMbps, closeTo(10.0, 1e-9));
    });
  });

  group('ServerCumulativeTracker upload (desktop)', () {
    test('falls back to client bytes when the server is silent', () {
      final tracker = const DesktopNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.desktop);
      // Pre-warm-up bytes are excluded from the fallback anchor.
      tracker.onClientBytes(500000, const Duration(seconds: 1));
      expect(tracker.throughputMbps, isNull);
      // Crossing the 2s warm-up anchors the fallback here.
      tracker.onClientBytes(1000000, const Duration(seconds: 2));
      // 5500000 bytes over 2s after warm-up end = 22 Mbps.
      tracker.onClientBytes(6500000, const Duration(seconds: 4));
      expect(tracker.throughputMbps, closeTo(8 * 5500000 / 2 / 1e6, 1e-9));
    });

    test('uses the latest cumulative BytesReceived sample', () {
      final tracker = const DesktopNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.desktop);
      // 1000000 bytes over 2s = 4 Mbps cumulative.
      tracker.onServerMeasurement(
        _tcpInfo(bytesReceived: 1000000, elapsedUs: 2000000),
        const Duration(seconds: 2),
      );
      expect(tracker.throughputMbps, closeTo(4.0, 1e-9));
      // 3000000 bytes over 4s = 6 Mbps cumulative; last sample wins even
      // though the instantaneous rate between samples is different.
      tracker.onServerMeasurement(
        _tcpInfo(bytesReceived: 3000000, elapsedUs: 4000000),
        const Duration(seconds: 4),
      );
      expect(tracker.throughputMbps, closeTo(6.0, 1e-9));
    });

    test('ignores BytesSent for upload', () {
      final tracker = const DesktopNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _tcpInfo(
            bytesSent: 99999999, bytesReceived: 1000000, elapsedUs: 2000000),
        const Duration(seconds: 2),
      );
      expect(tracker.throughputMbps, closeTo(4.0, 1e-9));
    });

    test('prefers AppInfo goodput when the server provides it', () {
      final tracker = const DesktopNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _appInfo(150),
        const Duration(seconds: 2),
      );
      expect(tracker.throughputMbps, closeTo(150.0, 1e-9));
    });
  });

  group('ClientSamplesTracker download (desktop)', () {
    test('returns null until client samples arrive', () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 99999999, elapsedUs: 5000000),
        const Duration(seconds: 5),
      );
      expect(tracker.throughputMbps, isNull,
          reason: 'server TCPInfo must not influence desktop download');
    });

    test('ignores samples inside the warm-up window', () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onClientBytes(1000000, const Duration(seconds: 1));
      expect(tracker.throughputMbps, isNull);
    });

    test('reports the median of collected samples (odd count)', () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      // Cumulative rates: 8 Mbps at 1.0s... warm-up is 2s, so samples start
      // after that.
      tracker.onClientBytes(3000000, const Duration(seconds: 3));
      tracker.onClientBytes(8000000, const Duration(seconds: 4));
      tracker.onClientBytes(15000000, const Duration(seconds: 5));
      // Samples: 8, 16, 24 Mbps -> median 16.
      expect(tracker.throughputMbps, closeTo(16.0, 1e-9));
    });

    test('reports the median of collected samples (even count)', () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onClientBytes(3000000, const Duration(seconds: 3));
      tracker.onClientBytes(8000000, const Duration(seconds: 4));
      // Samples: 8, 16 Mbps -> median 12.
      expect(tracker.throughputMbps, closeTo(12.0, 1e-9));
      tracker.onClientBytes(12000000, const Duration(seconds: 6));
      // Samples: 8, 16, 16 Mbps -> median 16.
      expect(tracker.throughputMbps, closeTo(16.0, 1e-9));
    });
  });

  group('strategies', () {
    test('mobile strategy reports its label', () {
      expect(const MobileNdt7Strategy().label, 'mobile');
    });

    test('desktop strategy reports its label', () {
      expect(const DesktopNdt7Strategy().label, 'desktop');
    });

    test('platform settings resolve to mobile on Android/iOS profiles', () {
      expect(Ndt7PlatformSettings.mobile.isMobile, isTrue);
      expect(Ndt7PlatformSettings.desktop.isMobile, isFalse);
      expect(Ndt7PlatformSettings.mobile.warmupDuration,
          const Duration(seconds: 2));
      expect(Ndt7PlatformSettings.desktop.warmupDuration,
          const Duration(seconds: 2));
      expect(Ndt7PlatformSettings.mobile.minSampleWindowUs, 100000);
      expect(Ndt7PlatformSettings.desktop.minSampleWindowUs, 25000);
    });
  });
}
