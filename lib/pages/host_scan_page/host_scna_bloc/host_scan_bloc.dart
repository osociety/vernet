import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:isolate_contactor/isolate_contactor.dart';
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

  @Deprecated("Now network_tools support running scan inside isolate")
  // ignore: unused_element
  Future<void> _startNewScan(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    const int scanRangeForIsolate = 51;
    for (int i = appSettings.firstSubnet;
        i <= appSettings.lastSubnet;
        i += scanRangeForIsolate + 1) {
      final IsolateContactor isolateContactor =
          await IsolateContactor.createOwnIsolate(startSearchingDevices);
      int limit = i + scanRangeForIsolate;
      if (limit >= appSettings.lastSubnet) {
        limit = appSettings.lastSubnet;
      }
      isolateContactor.sendMessage(<String>[
        subnet!,
        i.toString(),
        limit.toString(),
      ]);
      await for (final dynamic message in isolateContactor.onMessage) {
        try {
          if (message is ActiveHost) {
            final DeviceInTheNetwork tempDeviceInTheNetwork =
                DeviceInTheNetwork.createFromActiveHost(
              activeHost: message,
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
          } else if (message is String && message == 'Done') {
            isolateContactor.dispose();
          }
        } catch (e) {
          emit(const HostScanState.error());
        }
      }
    }
    debugPrint('The end of the scan');

    // emit(HostScanState.loadSuccess(activeHostList));
  }

  Future<void> _startNewScanBuiltInIsolate(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    final streamController = HostScanner.getAllPingableDevicesAsync(
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

  @Deprecated("Now network_tools support running scan inside isolate")

  /// Will search devices in the network inside new isolate
  static Future<void> startSearchingDevices(dynamic params) async {
    final channel = IsolateContactorController(params);
    channel.onIsolateMessage.listen((message) async {
      List<String> paramsListString = [];
      if (message is List<String>) {
        paramsListString = message;
      } else {
        return;
      }

      final String subnetIsolate = paramsListString[0];
      final int firstSubnetIsolate = int.parse(paramsListString[1]);
      final int lastSubnetIsolate = int.parse(paramsListString[2]);
      debugPrint('Scanning from $firstSubnetIsolate to $lastSubnetIsolate');

      /// Will contain all the hosts that got discovered in the network, will
      /// be use inorder to cancel on dispose of the page.
      final Stream<ActiveHost> hostsDiscoveredInNetwork =
          HostScanner.getAllPingableDevices(
        subnetIsolate,
        firstHostId: firstSubnetIsolate,
        lastHostId: lastSubnetIsolate,
      );

      await for (final ActiveHost activeHostFound in hostsDiscoveredInNetwork) {
        activeHostFound.deviceName.then((value) {
          activeHostFound.mdnsInfo.then((value) {
            activeHostFound.hostName.then((value) {
              channel.sendResult(activeHostFound);
            });
          });
        });
      }
      channel.sendResult('Done');
    });
  }
}
