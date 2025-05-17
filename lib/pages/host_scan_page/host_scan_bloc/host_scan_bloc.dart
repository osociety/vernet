import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/isar/scan.dart';
import 'package:vernet/repository/isar/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;

part 'host_scan_bloc.freezed.dart';
part 'host_scan_event.dart';
part 'host_scan_state.dart';

@injectable
class HostScanBloc extends Bloc<HostScanEvent, HostScanState> {
  HostScanBloc() : super(HostScanState.initial()) {
    on<Initialized>(_initialized);
    on<StartNewScan>(_startNewScanBuiltInIsolate);
    on<LoadScan>(_loadScanAndShowResults);
  }
  final scannerService = getIt<DeviceScannerService>();

  /// IP of the device in the local network.
  String? ip;

  /// Gateway IP of the current network
  late String? gatewayIp;

  String? subnet;

  /// List of all ActiveHost devices that got found in the current scan
  final Set<Device> devicesSet = {};

  /// mDNS for each ip
  final Map<String, MdnsInfo> mDnsDevices = {};

  Future<void> _initialized(
    Initialized event,
    Emitter<HostScanState> emit,
  ) async {
    final info = NetworkInfo();
    devicesSet.clear();
    mDnsDevices.clear();
    emit(const HostScanState.loadInProgress());
    String? wifiGatewayIP;
    try {
      wifiGatewayIP = await info.getWifiGatewayIP();
    } catch (e) {
      debugPrint('Unimplemented error $e');
    }

    final interface = await NetInterface.localInterface();
    ip = (await info.getWifiIP()) ?? interface?.ipAddress;
    debugPrint(
      'Local Network Id: ${interface?.networkId} and ip: ${interface?.ipAddress}',
    );
    if (appSettings.customSubnet.isNotEmpty) {
      gatewayIp = appSettings.customSubnet;
      debugPrint('Taking gatewayIp from appSettings: $gatewayIp');
    } else if (wifiGatewayIP != null) {
      gatewayIp = wifiGatewayIP;
      debugPrint(
        'Taking gatewayIp from NetworkInfo().getWifiGatewayIP(): $gatewayIp',
      );
    } else if (ip != null) {
      // NetworkInfo().getWifiGatewayIP() is null on android 35, so fail-safe
      // to NetworkInfo().getWifiIP()
      gatewayIp = ip;
      debugPrint('Taking gatewayIp from NetworkInfo().getWifiIP(): $gatewayIp');
    } else if (interface != null) {
      gatewayIp = interface.ipAddress;
      debugPrint(
        'Taking gatewayIp from NetInterface.localInterface(): $gatewayIp',
      );
    }
    if (gatewayIp == null) {
      emit(const HostScanState.error());
      return Future.error('Can not get wifi details');
    }
    subnet = gatewayIp!.substring(0, gatewayIp!.lastIndexOf('.'));
    if (subnet == null) {
      emit(const HostScanState.error());
      return Future.error('Can not get wifi details');
    }
    if (appSettings.runScanOnStartup) {
      add(const HostScanEvent.loadScan());
    } else {
      add(const HostScanEvent.startNewScan());
    }
  }

  Future<void> _startNewScanBuiltInIsolate(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());
    debugPrint(
      'Starting new scan with subnet: $subnet, ip: $ip, gatewayIp: $gatewayIp',
    );

    final deviceStream =
        getIt<DeviceScannerService>().startNewScan(subnet!, ip!, gatewayIp!);
    await for (final Device device in deviceStream) {
      devicesSet.add(device);
      emit(const HostScanState.loadInProgress());
      emit(HostScanState.foundNewDevice(devicesSet));
    }
    debugPrint(
      'Testing mode enabled ${globals.testingActive}',
    );

    if (!globals.testingActive) {
      // Because notification is not working in test mode in github actions
      await NotificationService.showNotificationWithActions();
      return;
    }

    emit(HostScanState.loadSuccess(devicesSet));
  }

  Future<void> _loadScanAndShowResults(
    LoadScan event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());

    final deviceStream = await getIt<DeviceScannerService>().getOnGoingScan();
    deviceStream.listen((devices) {
      devicesSet.addAll(devices);
      emit(const HostScanState.loadInProgress());
      emit(HostScanState.foundNewDevice(devicesSet));
    });

    //load success based on scan record getting updated to ongoing = false
    final currentScanId = await getCurrentScanId();
    if (currentScanId != null) {
      final scanStream = await getIt<ScanRepository>().watch(currentScanId);
      await for (final List<Scan> scanList in scanStream) {
        final scan = scanList.first;
        if (scan.onGoing == false) {
          emit(HostScanState.loadSuccess(devicesSet));
          break;
        }
      }
    }
  }
}
