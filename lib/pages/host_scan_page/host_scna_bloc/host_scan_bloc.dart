import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/host_scan_page/device_in_the_network.dart';

part 'host_scan_bloc.freezed.dart';
part 'host_scan_event.dart';
part 'host_scan_state.dart';

@injectable
class HostScanBloc extends Bloc<HostScanEvent, HostScanState> {
  HostScanBloc() : super(HostScanState.initial()) {
    on<Initialized>(_initialized);
    on<StartNewScan>(_startNewScanBuiltInIsolate);
  }

  /// IP of the device in the local network.
  String? ip;

  /// Gateway IP of the current network
  late String? gatewayIp;

  String? subnet;

  /// List of all ActiveHost devices that got found in the current scan
  List<DeviceInTheNetwork> activeHostList = [];

  Future<void> _initialized(
    Initialized event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());
    ip = await NetworkInfo().getWifiIP();
    subnet = ip!.substring(0, ip!.lastIndexOf('.'));
    gatewayIp = await NetworkInfo().getWifiGatewayIP();

    add(const HostScanEvent.startNewScan());
  }

  Future<void> _startNewScanBuiltInIsolate(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    final streamController = HostScannerFlutter.getAllPingableDevices(
      subnet!,
      firstHostId: appSettings.firstSubnet,
      lastHostId: appSettings.lastSubnet,
    );
    await for (final ActiveHost activeHost in streamController) {
      final DeviceInTheNetwork tempDeviceInTheNetwork =
          DeviceInTheNetwork.createFromActiveHost(
        activeHost: activeHost,
        currentDeviceIp: ip!,
        gatewayIp: gatewayIp!,
      );

      activeHostList.add(tempDeviceInTheNetwork);
      activeHostList.sort((a, b) {
        final int aIp = int.parse(
          a.internetAddress.address
              .substring(a.internetAddress.address.lastIndexOf('.') + 1),
        );
        final int bIp = int.parse(
          b.internetAddress.address
              .substring(b.internetAddress.address.lastIndexOf('.') + 1),
        );
        return aIp.compareTo(bIp);
      });
      emit(const HostScanState.loadInProgress());
      emit(HostScanState.foundNewDevice(activeHostList));
    }
  }
}
