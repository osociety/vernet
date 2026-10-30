import 'dart:async';
import 'dart:io';

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

  /// Progress can keep arriving after the page is gone; that must never throw
  /// inside the scan, which would abort it.
  void _setProgress(double value) {
    if (_progressDisposed) return;
    progress.value = value;
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

  /// The /24 prefix of every non-loopback IPv4 interface, used to tell a live
  /// network report from a stale one.
  static Future<Set<String>> _localInterfaceSubnets() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return {
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (address.address.contains('.'))
            address.address.substring(0, address.address.lastIndexOf('.')),
    };
  }

  /// True when [candidate] sits on a subnet this device actually has, or when
  /// no interface could be enumerated and there is nothing to check against.
  static bool _onKnownSubnet(String candidate, Set<String> knownSubnets) {
    if (knownSubnets.isEmpty) return true;
    final lastDot = candidate.lastIndexOf('.');
    return lastDot > 0 &&
        knownSubnets.contains(candidate.substring(0, lastDot));
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
    final wifiIp = await info.getWifiIP();
    debugPrint(
      'Local Network Id: ${interface?.networkId} and ip: ${interface?.ipAddress}',
    );

    // network_info_plus keeps reporting the last Wi-Fi network it saw even after
    // the device has left it: the Android emulator answers 192.168.1.x while
    // sitting on 10.0.2.x, and a Mac joined to a hotspot does the same. Scanning
    // such a subnet has no route, so every probe runs to its timeout and the
    // scan looks hung. Accept a reported address only when a real interface is
    // on that subnet.
    final knownSubnets = await _localInterfaceSubnets();
    ip = wifiIp != null && _onKnownSubnet(wifiIp, knownSubnets)
        ? wifiIp
        : interface?.ipAddress ?? wifiIp;

    if (appSettings.customSubnet.isNotEmpty) {
      gatewayIp = appSettings.customSubnet;
      debugPrint('Taking gatewayIp from appSettings: $gatewayIp');
    } else {
      // getWifiGatewayIP() is null on android 35, so the device's own address is
      // the fail-safe; only its subnet prefix is used from here on.
      final detected = <String, String?>{
        'NetworkInfo().getWifiGatewayIP()': wifiGatewayIP,
        'NetworkInfo().getWifiIP()': wifiIp,
        'NetInterface.localInterface()': interface?.ipAddress,
      };
      for (final source in detected.entries) {
        final value = source.value;
        if (value == null) continue;
        if (!_onKnownSubnet(value, knownSubnets)) {
          debugPrint(
            'Ignoring ${source.key} $value: no local interface is on that '
            'subnet (known: ${knownSubnets.join(', ')})',
          );
          continue;
        }
        gatewayIp = value;
        debugPrint('Taking gatewayIp from ${source.key}: $gatewayIp');
        break;
      }
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
    _setProgress(0);

    try {
      final deviceStream = getIt<DeviceScannerService>().startNewScan(
        subnet!,
        ip!,
        gatewayIp!,
        onProgress: _setProgress,
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
    _setProgress(100);
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
    _setProgress(0);

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
            _setProgress(100);
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
      _setProgress(100);
      emit(HostScanState.loadSuccess(Set<DeviceData>.of(devicesSet)));
    }
  }
}
