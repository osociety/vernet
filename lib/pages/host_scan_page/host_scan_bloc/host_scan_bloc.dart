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
import 'package:vernet/models/device_in_the_network.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/isar/scan.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/repository/scan_repository.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';

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
  final List<DeviceInTheNetwork> deviceInTheNetworkList = [];

  /// mDNS for each ip
  final Map<String, MdnsInfo> mDnsDevices = {};

  Future<void> _initialized(
    Initialized event,
    Emitter<HostScanState> emit,
  ) async {
    deviceInTheNetworkList.clear();
    mDnsDevices.clear();
    emit(const HostScanState.loadInProgress());
    ip = await NetworkInfo().getWifiIP();
    gatewayIp = appSettings.customSubnet.isNotEmpty
        ? appSettings.customSubnet
        : await NetworkInfo().getWifiGatewayIP();
    subnet = gatewayIp!.substring(0, gatewayIp!.lastIndexOf('.'));
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

    final Set<Device> devices = {};
    final deviceStream =
        getIt<DeviceScannerService>().startNewScan(subnet!, ip!, gatewayIp!);
    await for (final Device device in deviceStream) {
      devices.add(device);
      emit(HostScanState.foundNewDevice(devices));
    }

    await NotificationService.showNotificationWithActions();
    emit(HostScanState.loadSuccess(devices));
  }

  Future<void> _loadScanAndShowResults(
    LoadScan event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());

    final Set<Device> devicesSet = {};
    final deviceStream = await getIt<DeviceScannerService>().getOnGoingScan();
    deviceStream.listen((devices) {
      devicesSet.addAll(devices);
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
          await NotificationService.showNotificationWithActions();
          break;
        }
      }
    }
  }
}
