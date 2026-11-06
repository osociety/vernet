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

  group('ServerDeltaTracker download', () {
    test('ignores server measurements before warm-up completes', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      tracker.onServerMeasurement(_tcpInfo(bytesSent: 100, elapsedUs: 1000),
          const Duration(milliseconds: 500));
      expect(tracker.throughputMbps, isNull);
    });

    test('computes throughput from consecutive TCPInfo deltas after warm-up',
        () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      // Warm-up is 2s; first sample after it anchors the accumulator.
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1000000, elapsedUs: 3000000),
        const Duration(seconds: 3),
      );
      expect(tracker.throughputMbps, isNull);
      // 250000 bytes over 200000us = 10 Mbps.
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1250000, elapsedUs: 3200000),
        const Duration(seconds: 3, milliseconds: 200),
      );
      expect(tracker.throughputMbps, closeTo(10.0, 1e-9));
    });

    test('falls back to post-warm-up client average when server is silent', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      tracker.onClientBytes(2000000, const Duration(seconds: 2));
      expect(tracker.throughputMbps, isNull,
          reason: 'no bytes transferred after warm-up yet');
      // 8000000 bytes over 2s after warm-up end = 32 Mbps.
      tracker.onClientBytes(10000000, const Duration(seconds: 4));
      expect(tracker.throughputMbps, closeTo(32.0, 1e-9));
    });

    test('client fallback excludes pre-warm-up bytes', () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      tracker.onClientBytes(1000000, const Duration(seconds: 1));
      tracker.onClientBytes(2000000, const Duration(seconds: 2));
      // Only 4000000 of the 5000000 total count: slow-start is excluded.
      tracker.onClientBytes(7000000, const Duration(seconds: 4));
      expect(tracker.throughputMbps, closeTo(8 * 5000000 / 2 / 1e6, 1e-9));
    });

    test('ignores AppInfo throughput (mobile download uses TCPInfo deltas)',
        () {
      final tracker = const MobileNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.mobile);
      tracker.onServerMeasurement(_appInfo(999), const Duration(seconds: 3));
      expect(tracker.throughputMbps, isNull);
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

  group('ServerDeltaTracker upload (desktop)', () {
    test('falls back to client bytes like the download tracker', () {
      final tracker = const DesktopNdt7Strategy()
          .createUploadTracker(Ndt7PlatformSettings.desktop);
      tracker.onClientBytes(500000, const Duration(seconds: 1));
      tracker.onClientBytes(6500000, const Duration(seconds: 3));
      expect(tracker.throughputMbps, closeTo(8 * 6000000 / 2 / 1e6, 1e-9));
    });
  });

  group('AppInfo preference', () {
    test('desktop tracker prefers AppInfo goodput over TCPInfo deltas', () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _appInfo(180),
        const Duration(seconds: 2),
      );
      expect(tracker.throughputMbps, closeTo(180.0, 1e-9));
    });

    test('desktop tracker still uses TCPInfo deltas when AppInfo is absent',
        () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1000000, elapsedUs: 2000000),
        const Duration(seconds: 2),
      );
      // 250000 bytes over 100000us (desktop min window) = 20 Mbps.
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1250000, elapsedUs: 2100000),
        const Duration(seconds: 2, milliseconds: 100),
      );
      expect(tracker.throughputMbps, closeTo(20.0, 1e-9));
    });

    test('AppInfo without a throughput value does not block TCPInfo deltas',
        () {
      final tracker = const DesktopNdt7Strategy()
          .createDownloadTracker(Ndt7PlatformSettings.desktop);
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1000000, elapsedUs: 2000000),
        const Duration(seconds: 2),
      );
      tracker.onServerMeasurement(
        _tcpInfo(bytesSent: 1250000, elapsedUs: 2100000),
        const Duration(seconds: 2, milliseconds: 100),
      );
      // AppInfo with a null throughput must not evict the TCPInfo estimate.
      tracker.onServerMeasurement(
        const Ndt7Measurement(bytesSent: 1),
        const Duration(seconds: 2, milliseconds: 200),
      );
      expect(tracker.throughputMbps, closeTo(20.0, 1e-9));
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
          const Duration(seconds: 1));
      expect(Ndt7PlatformSettings.mobile.minSampleWindowUs, 100000);
      expect(Ndt7PlatformSettings.desktop.minSampleWindowUs, 25000);
    });
  });
}
