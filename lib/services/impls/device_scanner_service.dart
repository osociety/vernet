import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;

@visibleForTesting
Future<String> getWifiSubnetMaskOrDefault(
  Future<String?> Function() getWifiSubmask, {
  bool useFallback = false,
}) async {
  if (useFallback) return '255.255.255.0';

  try {
    return await getWifiSubmask() ?? '255.255.255.0';
    // ignore: avoid_catching_errors
  } on TypeError catch (error) {
    debugPrint('Failed to read Wi-Fi subnet mask: $error');
    return '255.255.255.0';
  }
}

@Injectable()
class DeviceScannerService extends ScannerService {
  static final _scanRepository = getIt<ScanRepository>();
  static final _deviceRepository = getIt<DeviceRepository>();

  static int _lastDeviceId = 0;

  /// Process-wide unique id for a device row.
  ///
  /// Discovery handlers run concurrently, so two hosts found in the same
  /// microsecond would otherwise collide on the primary key.
  static int _newDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (now > _lastDeviceId) _lastDeviceId = now;
    return _lastDeviceId++;
  }

  @override
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp, {
    void Function(double progress)? onProgress,
  }) {
    late final StreamController<DeviceData> controller;
    StreamSubscription<ActiveHost>? hostSubscription;
    final discoveryDone = Completer<void>();
    Object? discoveryError;
    StackTrace? discoveryStackTrace;
    var cancelled = false;

    // Rows inserted by this scan, keyed by address. Discovery and mDNS report
    // the same hosts, and details resolve later, so every lookup goes through
    // memory instead of a database round trip per host.
    final deviceByAddress = <String, DeviceData>{};

    void emitDevice(DeviceData device) {
      if (controller.isClosed || !controller.hasListener) return;
      controller.add(device);
    }

    Future<DeviceData> updateDevice(
      DeviceData device, {
      String? macAddress,
      String? hostMake,
      String? mdnsDomainName,
    }) async {
      final updated = DeviceData(
        id: device.id,
        internetAddress: device.internetAddress,
        macAddress: macAddress ?? device.macAddress,
        hostMake: hostMake ?? device.hostMake,
        mdnsDomainName: mdnsDomainName ?? device.mdnsDomainName,
        currentDeviceIp: device.currentDeviceIp,
        gatewayIp: device.gatewayIp,
        scanId: device.scanId,
      );
      await _deviceRepository.update(updated);
      deviceByAddress[updated.internetAddress] = updated;
      return updated;
    }

    Future<void> handleDiscoveredHost(
      ActiveHost activeHost,
      int scanId,
    ) async {
      try {
        final existing = deviceByAddress[activeHost.address];
        if (existing != null) {
          emitDevice(existing);
          return;
        }

        // Details resolve lazily in the scanner, so show the host as soon as
        // it is discovered instead of waiting for reverse DNS.
        final macAddress = await _macAddressOf(activeHost);
        var device = await _deviceRepository.put(
          DeviceData(
            id: _newDeviceId(),
            internetAddress: activeHost.address,
            macAddress: macAddress,
            currentDeviceIp: ip,
            gatewayIp: gatewayIp,
            scanId: scanId,
          ),
        );
        deviceByAddress[device.internetAddress] = device;
        emitDevice(device);
        debugPrint('Device found: ${device.internetAddress}');

        final name = await _deviceNameOf(activeHost);
        if (name == null || name == device.hostMake) return;
        device = await updateDevice(device, hostMake: name);
        emitDevice(device);
      } catch (error) {
        debugPrint('Failed to store device ${activeHost.address}: $error');
      }
    }

    Future<void> handleMdnsHost(ActiveHost activeHost, int scanId) async {
      try {
        final mdnsInfo = await activeHost.mdnsInfo;
        if (mdnsInfo == null) return;

        final existing = deviceByAddress[activeHost.address];
        if (existing != null) {
          final name = await _deviceNameOf(activeHost);
          final mdnsDomainName = mdnsInfo.mdnsDomainName;
          if (existing.mdnsDomainName == mdnsDomainName &&
              (name == null || name == existing.hostMake)) {
            return;
          }
          emitDevice(
            await updateDevice(
              existing,
              hostMake: name,
              mdnsDomainName: mdnsDomainName,
            ),
          );
          return;
        }

        final device = await _deviceRepository.put(
          DeviceData(
            id: _newDeviceId(),
            internetAddress: activeHost.address,
            macAddress: await _macAddressOf(activeHost),
            hostMake: await _deviceNameOf(activeHost),
            mdnsDomainName: mdnsInfo.mdnsDomainName,
            currentDeviceIp: ip,
            gatewayIp: gatewayIp,
            scanId: scanId,
          ),
        );
        deviceByAddress[device.internetAddress] = device;
        emitDevice(device);
        debugPrint('Device found via mDNS: ${device.internetAddress}');
      } catch (error) {
        debugPrint('Failed to store mDNS device ${activeHost.address}: $error');
      }
    }

    Future<void> runScan() async {
      ScanData? scan;
      final detailUpdates = <Future<void>>[];
      try {
        scan = await _scanRepository.put(
          ScanData(
            id: DateTime.now().millisecondsSinceEpoch,
            gatewayIp: subnet,
            startTime: DateTime.now(),
            onGoing: true,
          ),
        );
        final scanId = scan.id;
        await storeCurrentScanId(scanId);

        // mDNS discovery does not depend on the ICMP/ARP sweep; overlapping
        // them keeps the overall scan as short as the slower of the two.
        final mdnsSearch = globals.testingActive
            ? Future<List<ActiveHost>>.value(const [])
            : _searchMdnsDevicesSafely();

        final subnetMask = await getWifiSubnetMaskOrDefault(
          NetworkInfo().getWifiSubmask,
          useFallback: globals.testingActive,
        );
        final effectiveRange =
            (appSettings.firstSubnet == 1 && appSettings.lastSubnet == 254)
                ? appSettings.calculateHostRange(gatewayIp, subnetMask)
                : (
                    first: appSettings.firstSubnet,
                    last: appSettings.lastSubnet,
                  );

        final seenAddresses = <String>{};
        debugPrint(
          'Scanning host ids ${effectiveRange.first}..${effectiveRange.last} '
          'on subnet $subnet',
        );
        hostSubscription = HostScannerService.instance
            .getAllPingableDevices(
          subnet,
          firstHostId: effectiveRange.first,
          lastHostId: effectiveRange.last,
          progressCallback: onProgress,
        )
            .listen(
          (ActiveHost activeHost) {
            if (cancelled || !seenAddresses.add(activeHost.address)) return;
            detailUpdates.add(handleDiscoveredHost(activeHost, scanId));
          },
          onError: (Object error, StackTrace stackTrace) {
            discoveryError ??= error;
            discoveryStackTrace ??= stackTrace;
            if (!discoveryDone.isCompleted) discoveryDone.complete();
          },
          onDone: () {
            if (!discoveryDone.isCompleted) discoveryDone.complete();
          },
          cancelOnError: false,
        );

        await discoveryDone.future;
        if (discoveryError != null) {
          Error.throwWithStackTrace(discoveryError!, discoveryStackTrace!);
        }
        if (cancelled) return;

        // Name resolution runs concurrently; wait for the host rows to settle
        // before merging mDNS results so both paths never insert the same IP.
        await Future.wait(detailUpdates);
        if (cancelled) return;

        final mdnsUpdates = <Future<void>>[];
        final seenMdnsAddresses = <String>{};
        for (final ActiveHost activeHost in await mdnsSearch) {
          if (cancelled) return;
          if (!seenMdnsAddresses.add(activeHost.address)) continue;
          mdnsUpdates.add(handleMdnsHost(activeHost, scanId));
        }
        await Future.wait(mdnsUpdates);
      } catch (error, stackTrace) {
        debugPrint('Host scan failed: $error');
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        cancelled = true;
        await hostSubscription?.cancel();
        if (scan != null) await _finishScan(scan, subnet);
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<DeviceData>(
      onListen: () => unawaited(runScan()),
      onCancel: () async {
        cancelled = true;
        if (!discoveryDone.isCompleted) discoveryDone.complete();
        await hostSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _finishScan(ScanData scan, String subnet) async {
    try {
      await _scanRepository.update(
        ScanData(
          id: scan.id,
          gatewayIp: subnet,
          onGoing: false,
          endTime: DateTime.now(),
        ),
      );
      debugPrint('Scan ended');
    } catch (error) {
      debugPrint('Failed to finish scan ${scan.id}: $error');
    }
  }

  Future<List<ActiveHost>> _searchMdnsDevicesSafely() async {
    try {
      return await MdnsScannerService.instance.searchMdnsDevices();
    } catch (error) {
      debugPrint('Error searching mdns devices: $error');
      return const <ActiveHost>[];
    }
  }

  Future<String?> _macAddressOf(ActiveHost activeHost) async {
    try {
      return await activeHost.getMacAddress();
    } catch (error) {
      debugPrint('Failed to read MAC for ${activeHost.address}: $error');
      return null;
    }
  }

  Future<String?> _deviceNameOf(ActiveHost activeHost) async {
    try {
      final mdnsDomainName = (await activeHost.mdnsInfo)?.mdnsDomainName;
      if (mdnsDomainName != null && mdnsDomainName.isNotEmpty) {
        return mdnsDomainName;
      }
      return await activeHost.deviceName;
    } catch (error) {
      debugPrint('Failed to resolve name for ${activeHost.address}: $error');
      return null;
    }
  }

  @override
  Future<Stream<List<DeviceData>>> getOnGoingScan() async {
    final scan = await _scanRepository.getOnGoingScan();
    if (scan != null) {
      return await _deviceRepository.watch(scan.id);
    }
    return const Stream.empty();
  }

  Future<int> getCurrentDevicesCount() async {
    final scan = await _scanRepository.getOnGoingScan();
    if (scan != null) {
      return await _deviceRepository.countByScanId(scan.id);
    }
    return 0;
  }
}
