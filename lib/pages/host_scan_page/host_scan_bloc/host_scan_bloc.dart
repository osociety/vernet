import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
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
    add(const HostScanEvent.startNewScan());
  }

  Future<void> _startNewScanBuiltInIsolate(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    final streamController = HostScannerService.instance.getAllPingableDevices(
      subnet!,
      firstHostId: appSettings.firstSubnet,
      lastHostId: appSettings.lastSubnet,
    );
    await for (final ActiveHost activeHost in streamController) {
      final int index = indexOfActiveHost(activeHost.address);

      if (index == -1) {
        deviceInTheNetworkList.add(
          DeviceInTheNetwork.createFromActiveHost(
            activeHost: activeHost,
            currentDeviceIp: ip!,
            gatewayIp: gatewayIp!,
            mac: (await activeHost.arpData)?.macAddress,
          ),
        );
      } else {
        deviceInTheNetworkList[index] = DeviceInTheNetwork.createFromActiveHost(
          activeHost: activeHost,
          currentDeviceIp: ip!,
          gatewayIp: gatewayIp!,
          mdns: deviceInTheNetworkList[index].mdns,
          mac: (await activeHost.arpData)?.macAddress,
        );
      }

      deviceInTheNetworkList.sort(sort);
      emit(const HostScanState.loadInProgress());
      emit(HostScanState.foundNewDevice(deviceInTheNetworkList));
    }

    final activeMdnsHostList =
        await MdnsScannerService.instance.searchMdnsDevices();

    for (final ActiveHost activeHost in activeMdnsHostList) {
      final int index = indexOfActiveHost(activeHost.address);
      final MdnsInfo? mDns = await activeHost.mdnsInfo;
      if (mDns == null) {
        continue;
      }

      if (index == -1) {
        deviceInTheNetworkList.add(
          DeviceInTheNetwork.createFromActiveHost(
            activeHost: activeHost,
            currentDeviceIp: ip!,
            gatewayIp: gatewayIp!,
            mdns: mDns,
            mac: (await activeHost.arpData)?.macAddress,
          ),
        );
      } else {
        deviceInTheNetworkList[index] = deviceInTheNetworkList[index]
          ..mdns = mDns;
      }

      deviceInTheNetworkList.sort(sort);
      emit(const HostScanState.loadInProgress());
      emit(HostScanState.foundNewDevice(deviceInTheNetworkList));
    }
    emit(HostScanState.loadSuccess(deviceInTheNetworkList));
  }

  /// Getting active host IP and finds it's index inside of activeHostList
  /// Returns -1 if didn't find
  int indexOfActiveHost(String ip) {
    return deviceInTheNetworkList
        .indexWhere((element) => element.internetAddress.address == ip);
  }

  int sort(DeviceInTheNetwork a, DeviceInTheNetwork b) {
    final regexA = a.internetAddress.address.contains('.') ? '.' : '::';
    final regexB = b.internetAddress.address.contains('.') ? '.' : '::';
    if (regexA.length == 2 || regexB.length == 2) {
      return regexA.length.compareTo(regexB.length);
    }
    final int aIp = int.parse(
      a.internetAddress.address.substring(
        a.internetAddress.address.lastIndexOf(regexA) + regexA.length,
      ),
    );
    final int bIp = int.parse(
      b.internetAddress.address.substring(
        b.internetAddress.address.lastIndexOf(regexB) + regexB.length,
      ),
    );

    return aIp.compareTo(bIp);
  }
}
