import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/app_settings.dart';

typedef IcmpHostProbe = Future<bool> Function(String host, int timeoutSeconds);

typedef TcpHostScan = Stream<ActiveHost> Function(
  String subnet,
  List<int> hostIds,
  int timeoutSeconds,
  void Function(double progress)? onProgress,
);

/// Host discovery that applies the saved scan behavior settings.
///
/// ICMP mode probes hosts directly and reports only ping responders. The TCP
/// mode delegates to the network_tools sweep, split into batches so a lower
/// concurrency limit is honored; the sweep keeps its own platform ceiling.
class HostScanBehaviorService {
  HostScanBehaviorService({
    IcmpHostProbe? icmpProbe,
    TcpHostScan? tcpHostScan,
  })  : _icmpProbe = icmpProbe,
        _tcpHostScan = tcpHostScan ?? _tcpFallbackScan;

  final IcmpHostProbe? _icmpProbe;
  final TcpHostScan _tcpHostScan;

  Stream<ActiveHost> scan({
    required String subnet,
    required int firstHostId,
    required int lastHostId,
    required int timeoutSeconds,
    required int concurrency,
    required ScanPingMethod pingMethod,
    void Function(double progress)? onProgress,
  }) {
    final hostCount = lastHostId - firstHostId + 1;
    final activePings = <Ping>{};
    var cancelled = false;
    StreamSubscription<ActiveHost>? tcpSubscription;
    Completer<void>? pendingBatch;
    late final StreamController<ActiveHost> controller;

    Future<void> stopActivePings() async {
      final pings = activePings.toList();
      activePings.clear();
      await Future.wait(
        pings.map((ping) async {
          await ping.stop();
        }),
      );
    }

    Future<void> runScan() async {
      try {
        if (hostCount <= 0) return;

        final effectiveConcurrency = concurrency.clamp(1, hostCount);
        // The package sweep already runs up to the platform's recommended
        // concurrency in one pass, so only split it when a lower limit is
        // requested; otherwise the default scan would pay an isolate spawn per
        // batch for no change in probe concurrency.
        final batchSize = pingMethod == ScanPingMethod.tcpFallback &&
                effectiveConcurrency >= AppSettings.recommendedScanConcurrency
            ? hostCount
            : effectiveConcurrency;
        final hostIds = [
          for (var hostId = firstHostId; hostId <= lastHostId; hostId++) hostId,
        ];

        for (var offset = 0; offset < hostIds.length; offset += batchSize) {
          if (cancelled) return;
          final batch = hostIds.skip(offset).take(batchSize).toList();

          if (pingMethod == ScanPingMethod.icmp) {
            var completed = 0;
            final results = await Future.wait(
              batch.map((hostId) async {
                final host = '$subnet.$hostId';
                final found = _icmpProbe == null
                    ? await _icmpPing(host, timeoutSeconds, activePings)
                    : await _icmpProbe(host, timeoutSeconds);
                completed++;
                if (!cancelled) {
                  onProgress?.call((offset + completed) / hostCount * 100);
                }
                return found;
              }),
            );

            if (cancelled) return;
            for (var index = 0; index < batch.length; index++) {
              if (results[index]) {
                controller.add(_activeHost('$subnet.${batch[index]}'));
              }
            }
            continue;
          }

          void reportBatchProgress(double progress) {
            final boundedProgress = progress.clamp(0, 100).toDouble();
            if (!cancelled) {
              onProgress?.call(
                (offset + batch.length * boundedProgress / 100) /
                    hostCount *
                    100,
              );
            }
          }

          final batchDone = Completer<void>();
          pendingBatch = batchDone;
          tcpSubscription = _tcpHostScan(
            subnet,
            batch,
            timeoutSeconds,
            reportBatchProgress,
          ).listen(
            (host) {
              if (!cancelled) controller.add(host);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!batchDone.isCompleted) {
                batchDone.completeError(error, stackTrace);
              }
            },
            onDone: () {
              if (!batchDone.isCompleted) batchDone.complete();
            },
          );
          await batchDone.future;
          pendingBatch = null;
          tcpSubscription = null;
          if (cancelled) return;
          reportBatchProgress(100);
        }
      } catch (error, stackTrace) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        await tcpSubscription?.cancel();
        await stopActivePings();
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<ActiveHost>(
      onListen: () => unawaited(runScan()),
      onCancel: () async {
        cancelled = true;
        // Cancelling the subscription does not invoke its onDone, so an awaited
        // batch would never settle and runScan would never close the stream.
        final batch = pendingBatch;
        if (batch != null && !batch.isCompleted) batch.complete();
        await tcpSubscription?.cancel();
        await stopActivePings();
      },
    );
    return controller.stream;
  }

  static Stream<ActiveHost> _tcpFallbackScan(
    String subnet,
    List<int> hostIds,
    int timeoutSeconds,
    void Function(double progress)? onProgress,
  ) {
    return HostScannerService.instance.getAllPingableDevices(
      subnet,
      firstHostId: hostIds.first,
      lastHostId: hostIds.last,
      hostIds: hostIds,
      timeoutInSeconds: timeoutSeconds,
      progressCallback: onProgress,
      resultsInAddressAscendingOrder: false,
    );
  }

  static ActiveHost _activeHost(String address) {
    return ActiveHost.fromSendableActiveHost(
      sendableActiveHost: SendableActiveHost(address),
    );
  }

  static Future<bool> _icmpPing(
    String host,
    int timeoutSeconds,
    Set<Ping> activePings,
  ) async {
    Ping? ping;
    try {
      ping = Ping(
        host,
        count: 1,
        timeout: timeoutSeconds,
        forceCodepage: Platform.isWindows,
      );
      activePings.add(ping);

      PingResponse? response;
      PingSummary? summary;
      await for (final event in ping.stream) {
        if (event is PingResponse && response == null) {
          response = event;
        } else if (event is PingSummary) {
          summary = event;
        }
        if (response != null && summary != null) break;
      }

      if (response == null || response.time == null || summary?.received == 0) {
        return false;
      }
      return response.ip == null || response.ip == host;
    } catch (error, stackTrace) {
      debugPrint('ICMP probe failed for $host: $error\n$stackTrace');
      return false;
    } finally {
      if (ping != null) activePings.remove(ping);
    }
  }
}
