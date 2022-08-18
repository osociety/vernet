import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:arp_scanner/arp_scanner.dart';
import 'package:arp_scanner/device.dart';
import 'package:bloc/bloc.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
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
    on<AddNewScanResult>(_addNewScanResult);
    on<StartNewScan>(_startNewScan);
    on<StartLocalArpScan>(_startLocalArpScan);
    on<StartNewPingScan>(_startNewPingScan);
  }

  /// IP of the device in the local network.
  String? currentDeviceIp;

  /// Gateway IP of the current network
  late String? gatewayIp;

  String? subnet;

  /// IP and DeviceInTheNetwork of that IP
  HashMap<String, DeviceInTheNetwork> activeHostHashMap =
      HashMap<String, DeviceInTheNetwork>();

  Future<void> _initialized(
    Initialized event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());
    currentDeviceIp = await NetworkInfo().getWifiIP();
    subnet = currentDeviceIp!.substring(0, currentDeviceIp!.lastIndexOf('.'));
    gatewayIp = await NetworkInfo().getWifiGatewayIP();

    add(const HostScanEvent.startNewScan());
  }

  Future<void> _addNewScanResult(
    AddNewScanResult event,
    Emitter<HostScanState> emit,
  ) async {
    final DeviceInTheNetwork newDeviceInTheNetwork = event.deviceInTheNetwork;

    if (!activeHostHashMap.containsKey(newDeviceInTheNetwork.hostDeviceIp)) {
      activeHostHashMap.addEntries([
        MapEntry(newDeviceInTheNetwork.hostDeviceIp, newDeviceInTheNetwork)
      ]);
    } else {
      final DeviceInTheNetwork currentDeviceInTheNetwork =
          activeHostHashMap[newDeviceInTheNetwork.hostDeviceIp]!;
      activeHostHashMap[newDeviceInTheNetwork.hostDeviceIp] =
          await combineDevicesInTheNetwork(
        currentDeviceInTheNetwork,
        newDeviceInTheNetwork,
      );
    }
    // /// List of all ActiveHost devices that got found in the current scan
    final List<DeviceInTheNetwork> activeHostList =
        activeHostHashMap.values.toList();

    activeHostList.sort((a, b) {
      final int aIp = int.parse(
        a.hostDeviceIp.substring(a.hostDeviceIp.lastIndexOf('.') + 1),
      );
      final int bIp = int.parse(
        b.hostDeviceIp.substring(b.hostDeviceIp.lastIndexOf('.') + 1),
      );
      return aIp.compareTo(bIp);
    });

    emit(const HostScanState.loadInProgress());
    emit(
      HostScanState.foundNewDevice(
        activeHostList: activeHostList,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      ),
    );
  }

  Future<void> _startNewScan(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    add(const HostScanEvent.startLocalArpScan());
    add(const HostScanEvent.startNewPingScan());
  }

  Future<void> _startLocalArpScan(
    StartLocalArpScan event,
    Emitter<HostScanState> emit,
  ) async {
    if (Platform.isAndroid) {
      String result = '';

      ArpScanner.onScanning.listen((Device device) {
        if (device.ip != null) {
          final DeviceInTheNetwork tempDeviceInTheNetwork = DeviceInTheNetwork(
            hostDeviceIp: device.ip!,
            name: Future.value(device.hostname),
            pingData: PingData(
              response: PingResponse(
                time: Duration(
                  milliseconds:
                      // TODO: check if time is in milliseconds
                      device.time.toInt(),
                ),
              ),
            ),
          );

          add(HostScanEvent.addNewScanResult(tempDeviceInTheNetwork));
          result =
              "${result}Mac:${device.mac} ip:${device.ip} hostname:${device.hostname} time:${device.time} vendor:${device.vendor} \n";
        }
      });
      ArpScanner.onScanFinished.listen((List<Device> devices) {
        result = "${result}total: ${devices.length}";
      });

      await ArpScanner.scan();
    }
  }

  Future<void> _startNewPingScan(
    StartNewPingScan event,
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
            );

            add(HostScanEvent.addNewScanResult(tempDeviceInTheNetwork));
          } else if (message is String && message == 'Done') {
            isolateContactor.dispose();
          }
        } catch (e) {
          emit(const HostScanState.error());
        }
      }
    }
    print('The end of the scan');

    // emit(HostScanState.loadSuccess(activeHostList));
  }

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
      print('scanning from $firstSubnetIsolate to $lastSubnetIsolate');

      /// Will contain all the hosts that got discovered in the network, will
      /// be use inorder to cancel on dispose of the page.
      final Stream<ActiveHost> hostsDiscoveredInNetwork =
          HostScanner.getAllPingableDevices(
        subnetIsolate,
        firstSubnet: firstSubnetIsolate,
        lastSubnet: lastSubnetIsolate,
      );

      await for (final ActiveHost activeHostFound in hostsDiscoveredInNetwork) {
        channel.sendResult(activeHostFound);
      }
      channel.sendResult('Done');
    });
  }

  Future<DeviceInTheNetwork> combineDevicesInTheNetwork(
    DeviceInTheNetwork currentDeviceInTheNetwork,
    DeviceInTheNetwork newDeviceInTheNetwork,
  ) async {
    if (currentDeviceInTheNetwork.mac == null &&
        newDeviceInTheNetwork.mac != null) {
      currentDeviceInTheNetwork.mac = newDeviceInTheNetwork.mac;
    }
    if (await currentDeviceInTheNetwork.getDeviceName() ==
            DeviceInTheNetwork.defaultName &&
        await newDeviceInTheNetwork.getDeviceName() !=
            DeviceInTheNetwork.defaultName) {
      currentDeviceInTheNetwork
          .setDeviceName(await newDeviceInTheNetwork.getDeviceName());
    }

    return currentDeviceInTheNetwork;
  }
}
