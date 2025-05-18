import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/scanner_service.dart';

@Injectable()
class DeviceScannerService extends ScannerService {
  static final _scanRepository = getIt<ScanRepository>();
  static final _deviceRepository = getIt<DeviceRepository>();

  @override
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp,
  ) async* {
    final scan = await _scanRepository.put(
      ScanData(
        id: DateTime.now().millisecondsSinceEpoch,
        gatewayIp: subnet,
        startTime: DateTime.now(),
        onGoing: true,
      ),
    );

    await storeCurrentScanId(scan.id);

    final streamController = HostScannerService.instance.getAllPingableDevices(
      subnet,
      firstHostId: appSettings.firstSubnet,
      lastHostId: appSettings.lastSubnet,
    );
    await for (final ActiveHost activeHost in streamController) {
      var device =
          await _deviceRepository.getDevice(scan.id, activeHost.address);
      if (device == null) {
        device = DeviceData(
          id: DateTime.now().millisecondsSinceEpoch,
          internetAddress: activeHost.address,
          macAddress: (await activeHost.arpData)?.macAddress,
          currentDeviceIp: ip,
          hostMake: await activeHost.deviceName,
          gatewayIp: gatewayIp,
          scanId: scan.id,
        );
        await _deviceRepository.put(device);
      }
      debugPrint('Device found: ${device.internetAddress}');
      yield device;
    }

    final activeMdnsHostList =
        await MdnsScannerService.instance.searchMdnsDevices();

    for (final ActiveHost activeHost in activeMdnsHostList) {
      var device =
          await _deviceRepository.getDevice(scan.id, activeHost.address);

      final MdnsInfo? mDns = await activeHost.mdnsInfo;
      if (mDns == null) {
        continue;
      }

      if (device == null) {
        device = DeviceData(
          id: DateTime.now().millisecondsSinceEpoch,
          internetAddress: activeHost.address,
          macAddress: (await activeHost.arpData)?.macAddress,
          hostMake: await activeHost.deviceName,
          currentDeviceIp: ip,
          gatewayIp: gatewayIp,
          scanId: scan.id,
        );
        await _deviceRepository.put(device);
      }
      debugPrint('Device found: ${device.internetAddress}');
      yield device;
    }

    await _scanRepository.update(
      ScanData(
        id: scan.id,
        gatewayIp: subnet,
        onGoing: false,
        endTime: DateTime.now(),
      ),
    );
    debugPrint('Scan ended');
  }

  @override
  Future<Stream<List<DeviceData>>> getOnGoingScan() async {
    final scan = await _scanRepository.getOnGoingScan();
    if (scan != null) {
      return _deviceRepository.watch(scan.id);
    }
    return const Stream.empty();
  }

  Future<int> getCurrentDevicesCount() async {
    final scan = await _scanRepository.getOnGoingScan();
    if (scan != null) {
      return _deviceRepository.countByScanId(scan.id);
    }
    return 0;
  }
}
