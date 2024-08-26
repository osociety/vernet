import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/isar/scan.dart';
import 'package:vernet/repository/device_repository.dart';
import 'package:vernet/repository/scan_repository.dart';
import 'package:vernet/services/scanner_service.dart';

@Injectable()
class DeviceScannerService extends ScannerService {
  static final _scanRepository = getIt<ScanRepository>();
  static final _deviceRepository = getIt<DeviceRepository>();

  @override
  Stream<Device> startNewScan(
    String subnet,
    String ip,
    String gatewayIp,
  ) async* {
    final scan = await _scanRepository.put(
      Scan(
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
        device = Device(
          internetAddress: activeHost.address,
          macAddress: (await activeHost.arpData)!.macAddress,
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
        device = Device(
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

    scan.endTime = DateTime.now();
    scan.onGoing = false;
    await _scanRepository.put(scan);
    debugPrint('Scan ended');
  }

  @override
  Future<Stream<List<Device>>> getOnGoingScan() async {
    final scan = await _scanRepository.getOnGoingScan();
    if (scan != null) {
      return _deviceRepository.watch(scan.id);
    }
    return const Stream.empty();
  }
}
