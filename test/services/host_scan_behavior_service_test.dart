import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/services/host_scan_behavior_service.dart';

void main() {
  group('HostScanBehaviorService', () {
    test('ICMP probes honor the concurrency and timeout settings', () async {
      final firstBatchStarted = Completer<void>();
      final releaseProbes = Completer<void>();
      final timeouts = <int>[];
      var activeProbes = 0;
      var maxActiveProbes = 0;
      var startedProbes = 0;

      final service = HostScanBehaviorService(
        icmpProbe: (host, timeoutSeconds) async {
          activeProbes++;
          startedProbes++;
          timeouts.add(timeoutSeconds);
          if (activeProbes > maxActiveProbes) {
            maxActiveProbes = activeProbes;
          }
          if (startedProbes == 3) firstBatchStarted.complete();

          await releaseProbes.future;
          activeProbes--;
          return host.endsWith('.2') || host.endsWith('.5');
        },
      );

      final scan = service
          .scan(
            subnet: '192.168.1',
            firstHostId: 1,
            lastHostId: 7,
            timeoutSeconds: 5,
            concurrency: 3,
            pingMethod: ScanPingMethod.icmp,
          )
          .toList();

      await firstBatchStarted.future;
      expect(startedProbes, 3);
      releaseProbes.complete();

      final hosts = await scan;
      expect(maxActiveProbes, 3);
      expect(timeouts, everyElement(5));
      expect(hosts.map((host) => host.address), ['192.168.1.2', '192.168.1.5']);
    });

    test('TCP fallback scans host IDs in concurrency-sized batches', () async {
      final batches = <List<int>>[];
      final timeouts = <int>[];
      final progress = <double>[];
      final service = HostScanBehaviorService(
        tcpHostScan: (subnet, hostIds, timeoutSeconds, onProgress) {
          batches.add(hostIds);
          timeouts.add(timeoutSeconds);
          onProgress?.call(100);
          return const Stream<ActiveHost>.empty();
        },
      );

      await service
          .scan(
            subnet: '192.168.1',
            firstHostId: 1,
            lastHostId: 7,
            timeoutSeconds: 2,
            concurrency: 3,
            pingMethod: ScanPingMethod.tcpFallback,
            onProgress: progress.add,
          )
          .toList();

      expect(batches, [
        [1, 2, 3],
        [4, 5, 6],
        [7],
      ]);
      expect(timeouts, everyElement(2));
      expect(progress.last, 100);
      expect(progress, orderedEquals(progress.toList()..sort()));
    });
  });
}
