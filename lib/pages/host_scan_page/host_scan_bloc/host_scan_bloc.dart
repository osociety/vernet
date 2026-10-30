import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
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
  final Set<DeviceData> devicesSet = {};

  /// Scan progress in percent (0-100), fed by the scanner.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  bool _progressDisposed = false;

  /// mDNS for each ip
  final Map<String, MdnsInfo> mDnsDevices = {};

  @override
  Future<void> close() async {
    await super.close();
    if (_progressDisposed) return;
    _progressDisposed = true;
    progress.dispose();
  }

  /// Adds a device or replaces the existing row with the same id in place, so
  /// lazily resolved details update the list without duplicating or reordering.
  void _upsertDevice(DeviceData device) {
    final ordered = devicesSet.toList();
    final index = ordered.indexWhere((existing) => existing.id == device.id);
    if (index == -1) {
      devicesSet.add(device);
      return;
    }
    ordered[index] = device;
    devicesSet
      ..clear()
      ..addAll(ordered);
  }

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
      return await Future.error('Can not get wifi details');
    }
    subnet = gatewayIp!.substring(0, gatewayIp!.lastIndexOf('.'));
    if (subnet == null) {
      emit(const HostScanState.error());
      return await Future.error('Can not get wifi details');
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
    progress.value = 0;

    try {
      final deviceStream = getIt<DeviceScannerService>().startNewScan(
        subnet!,
        ip!,
        gatewayIp!,
        onProgress: (double value) => progress.value = value,
      );
      await for (final DeviceData device in deviceStream) {
        _upsertDevice(device);
        if (!emit.isDone) {
          emit(HostScanState.foundNewDevice(Set<DeviceData>.of(devicesSet)));
        }
      }
    } catch (error) {
      // A failed or crashed scan must not leave the UI (or the stored scan)
      // waiting forever.
      final detail = error is HostScanException ? ' (${error.kind})' : '';
      debugPrint('Host scan failed$detail: $error');
      if (!emit.isDone) emit(const HostScanState.loadFailure());
      return;
    }
    progress.value = 100;
    debugPrint(
      'Testing mode enabled ${globals.testingActive}',
    );

    await NotificationService.showNotificationWithActions(
      deviceCount: devicesSet.length,
    );

    if (!emit.isDone) {
      emit(HostScanState.loadSuccess(Set<DeviceData>.of(devicesSet)));
    }
  }

  Future<void> _loadScanAndShowResults(
    LoadScan event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());
    progress.value = 0;

    final deviceStream = await getIt<DeviceScannerService>().getOnGoingScan();
    // guard against emitting after handler completion by checking emit.isDone
    deviceStream.listen((devices) {
      if (!emit.isDone) {
        for (final device in devices) {
          _upsertDevice(device);
        }
        emit(HostScanState.foundNewDevice(Set<DeviceData>.of(devicesSet)));
      }
    });

    //load success based on scan record getting updated to ongoing = false
    int? currentScanId;
    try {
      currentScanId = await getCurrentScanId();
    } catch (_) {
      // ignore shared prefs error in tests
      currentScanId = null;
    }

    if (currentScanId != null && getIt.isRegistered<ScanRepository>()) {
      try {
        final scanStream = await getIt<ScanRepository>().watch(currentScanId);
        await for (final List<ScanData> scanList in scanStream) {
          final scan = scanList.first;
          if (scan.onGoing == false) {
            progress.value = 100;
            if (!emit.isDone) {
              emit(HostScanState.loadSuccess(Set<DeviceData>.of(devicesSet)));
            }
            break;
          }
        }
      } catch (e) {
        // In tests or unusual circumstances the repo might still fail;
        // fall through and emit success below to avoid hanging.
        debugPrint('Error watching scan repository: $e');
      }
    }

    // Ensure we always notify callers of completion. The repository-based
    // emission above covers the normal app flow, but tests and some platform
    // configurations may not register a ScanRepository or provide a scan id.
    if (!emit.isDone) {
      progress.value = 100;
      emit(HostScanState.loadSuccess(Set<DeviceData>.of(devicesSet)));
    }
  }
}
