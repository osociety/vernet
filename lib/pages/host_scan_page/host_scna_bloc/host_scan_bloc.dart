import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
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
  List<DeviceInTheNetwork> deviceInTheNetworkList = [];

  /// mDNS for each ip
  Map<String, MdnsInfo> mDnsDevices = {};

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
    MdnsScanner.searchMdnsDevices()
        .then((List<ActiveHost> activeHostList) async {
      for (final ActiveHost activeHost in activeHostList) {
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
            ),
          );
        } else {
          deviceInTheNetworkList[index] = deviceInTheNetworkList[index]
            ..mdns = mDns;
        }

        deviceInTheNetworkList.sort((a, b) {
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
        emit(HostScanState.foundNewDevice(deviceInTheNetworkList));
      }
    });

    final streamController = HostScanner.getAllPingableDevicesAsync(
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
          ),
        );
      } else {
        deviceInTheNetworkList[index] = DeviceInTheNetwork.createFromActiveHost(
          activeHost: activeHost,
          currentDeviceIp: ip!,
          gatewayIp: gatewayIp!,
          mdns: deviceInTheNetworkList[index].mdns,
        );
      }

      deviceInTheNetworkList.sort((a, b) {
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
      emit(HostScanState.foundNewDevice(deviceInTheNetworkList));
    }
  }

  /// Getting active host IP and finds it's index inside of activeHostList
  /// Returns -1 if didn't find
  int indexOfActiveHost(String ip) {
    return deviceInTheNetworkList
        .indexWhere((element) => element.internetAddress.address == ip);
  }
}
