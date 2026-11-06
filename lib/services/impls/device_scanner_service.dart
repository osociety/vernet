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
      String? deviceType,
      String? openPorts,
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
        deviceType: deviceType ?? device.deviceType,
        openPorts: openPorts ?? device.openPorts,
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
        final openPortsStr =
            activeHost.openPorts.map((p) => p.port.toString()).join(',');
        debugPrint(
            'Host ${activeHost.address}: openPorts=${activeHost.openPorts.length}, ports=$openPortsStr, deviceType=${activeHost.deviceType}');
        var device = await _deviceRepository.upsertByAddress(
          DeviceData(
            id: _newDeviceId(),
            internetAddress: activeHost.address,
            macAddress: macAddress,
            currentDeviceIp: ip,
            gatewayIp: gatewayIp,
            scanId: scanId,
            deviceType: activeHost.deviceType,
            openPorts: openPortsStr.isEmpty ? null : openPortsStr,
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

        final openPortsStr =
            activeHost.openPorts.map((p) => p.port.toString()).join(',');
        final device = await _deviceRepository.upsertByAddress(
          DeviceData(
            id: _newDeviceId(),
            internetAddress: activeHost.address,
            macAddress: await _macAddressOf(activeHost),
            hostMake: await _deviceNameOf(activeHost),
            mdnsDomainName: mdnsInfo.mdnsDomainName,
            currentDeviceIp: ip,
            gatewayIp: gatewayIp,
            scanId: scanId,
            deviceType: activeHost.deviceType,
            openPorts: openPortsStr.isEmpty ? null : openPortsStr,
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

        // Clean up any existing devices for this scanId to prevent duplicates
        await _deviceRepository.deleteByScanId(scanId);

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
                    first: appSettings.firstSubnet.clamp(1, 254),
                    last: appSettings.lastSubnet.clamp(1, 254),
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
          // On Android the sweep is a system-ping-per-host process storm; the
          // ascending-order gate delays each row until every lower host id has
          // resolved. Unordered streams hosts as they are found. Trade-off: the
          // package emits no per-host progress in this mode, so the UI falls
          // back to its indeterminate state (already handled in host_scan_widget).
          resultsInAddressAscendingOrder: false,
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

        // Run quick port scans in background to enrich devices with open ports
        // and device type. This runs after discovery so the UI shows devices
        // immediately, then updates them as port data arrives.
        await _enrichDevicesWithPortScan(
            deviceByAddress.values.toList(), scanId, controller);

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

  /// Runs quick port scans on discovered devices in background to enrich them
  /// with open ports and device type. Uses bounded concurrency to avoid
  /// overwhelming the network.
  Future<void> _enrichDevicesWithPortScan(
    List<DeviceData> devices,
    int scanId,
    StreamController<DeviceData> controller,
  ) async {
    if (devices.isEmpty) return;

    debugPrint(
        'Starting background port scan enrichment for ${devices.length} devices');

    // Process devices with bounded concurrency (8 at a time)
    const maxConcurrency = 8;
    var index = 0;

    while (index < devices.length) {
      final batch = devices.skip(index).take(maxConcurrency).toList();
      final futures =
          batch.map((device) => _scanDevicePorts(device, scanId, controller));
      await Future.wait(futures);
      index += maxConcurrency;
    }

    debugPrint('Background port scan enrichment completed');
  }

  /// Runs a quick port scan on a single device and updates it with open ports
  /// and device type.
  Future<void> _scanDevicePorts(
    DeviceData device,
    int scanId,
    StreamController<DeviceData> controller,
  ) async {
    try {
      final stream = PortScannerService.instance.customDiscover(
        device.internetAddress,
        timeout: Duration(milliseconds: appSettings.socketTimeout),
        async: true,
      );

      // Collect all open ports from the stream
      final ports = <int>[];
      await for (final host in stream) {
        ports.addAll(host.openPorts.map((p) => p.port));
      }

      if (ports.isEmpty) return;

      final openPortsStr = ports.toSet().map((p) => p.toString()).join(',');
      final deviceType = _inferDeviceTypeFromPorts(ports.toSet().toList());

      final updated = DeviceData(
        id: device.id,
        internetAddress: device.internetAddress,
        macAddress: device.macAddress,
        hostMake: device.hostMake,
        mdnsDomainName: device.mdnsDomainName,
        currentDeviceIp: device.currentDeviceIp,
        gatewayIp: device.gatewayIp,
        scanId: device.scanId,
        openPorts: openPortsStr,
        deviceType: deviceType,
      );

      await _deviceRepository.update(updated);

      // Emit the updated device to the stream so the UI can refresh
      if (!controller.isClosed) {
        controller.add(updated);
      }

      debugPrint(
          'Enriched ${device.internetAddress}: ${ports.length} ports, type=$deviceType');
    } catch (error) {
      debugPrint('Failed to scan ports for ${device.internetAddress}: $error');
    }
  }

  /// Infers device type from open port numbers.
  String _inferDeviceTypeFromPorts(List<int> ports) {
    final portSet = ports.toSet();

    // Printer: IPP (631) or JetDirect (9100) - most specific
    if (portSet.contains(631) || portSet.contains(9100)) return 'Printer';

    // NAS: FTP (21) + SMB (445)
    if (portSet.contains(21) && portSet.contains(445)) return 'NAS';

    // Router/Gateway: DNS (53) is the key indicator, especially with other services
    if (portSet.contains(53)) {
      if (portSet.contains(161) ||
          portSet.contains(80) ||
          portSet.contains(443) ||
          portSet.contains(8080) ||
          portSet.contains(8443)) {
        return 'Router';
      }
      // DNS alone often indicates a router/gateway
      if (portSet.length == 1) return 'Router';
    }

    // Server: SSH + both HTTP and HTTPS
    if (portSet.contains(22) && portSet.contains(80) && portSet.contains(443)) {
      return 'Server';
    }

    // Linux Server: SSH + web services
    if (portSet.contains(22) &&
        (portSet.contains(80) ||
            portSet.contains(443) ||
            portSet.contains(8080))) {
      return 'Linux Server';
    }

    // Windows PC: SMB or RDP
    if (portSet.contains(445) || portSet.contains(3389)) return 'Windows PC';

    // Linux/Unix Device: SSH only
    if (portSet.contains(22) && portSet.length == 1) return 'Linux/Unix Device';

    // Web Device: HTTP + HTTPS only
    if (portSet.contains(80) && portSet.contains(443) && portSet.length == 2) {
      return 'Web Device';
    }

    // IoT Device: limited ports with HTTP/HTTPS
    if (portSet.length <= 2 &&
        (portSet.contains(80) ||
            portSet.contains(443) ||
            portSet.contains(8080))) {
      return 'IoT Device';
    }

    // Remote Display: VNC only
    if (portSet.contains(5900) && portSet.length == 1) return 'Remote Display';

    return 'Unknown Device';
  }
}
