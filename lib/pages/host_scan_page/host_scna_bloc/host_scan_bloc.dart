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
    on<StartNewScan>(_startNewScan);
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

  Future<void> _startNewScan(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    final List<String> paramsTemp = [
      subnet!,
      appSettings.firstSubnet.toString(),
      appSettings.lastSubnet.toString(),
    ];

    final IsolateContactor isolateContactor =
        await IsolateContactor.createOwnIsolate(startSearchingDevices);

    isolateContactor.sendMessage(paramsTemp);

    await for (final dynamic message in isolateContactor.onMessage) {
      try {
        if (message is List) {
          final String activeHostFoundIp = message[0] as String;
          final int activeHostFoundId = message[1] as int;
          final String activeHostFoundMake = message[2] as String;
          final PingData activeHostFoundPingData = message[3] as PingData;

          final DeviceInTheNetwork tempDeviceInTheNetwork =
              DeviceInTheNetwork.createWithAllNecessaryFields(
            ip: activeHostFoundIp,
            hostId: activeHostFoundId,
            make: activeHostFoundMake,
            pingData: activeHostFoundPingData,
            currentDeviceIp: ip!,
            gatewayIp: gatewayIp!,
          );

          activeHostList.add(tempDeviceInTheNetwork);
          emit(const HostScanState.loadInProgress());
          emit(HostScanState.foundNewDevice(activeHostList));
        }
      } catch (e) {
        emit(const HostScanState.error());
      }
    }
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

      /// Will contain all the hosts that got discovered in the network, will
      /// be use inorder to cancel on dispose of the page.
      final Stream<ActiveHost> hostsDiscoveredInNetwork = HostScanner.discover(
        subnetIsolate,
        firstSubnet: firstSubnetIsolate,
        lastSubnet: lastSubnetIsolate,
        // TODO: check why the results returned in ascending order although I
        // TODO: have added "false" here.
        resultsInIpAscendingOrder: false,
      );

      try {
        await for (final ActiveHost activeHostFound
            in hostsDiscoveredInNetwork) {
          channel.sendResult(
            [
              activeHostFound.ip,
              activeHostFound.hostId,
              activeHostFound.make,
              activeHostFound.pingData,
            ],
          );
        }
      } catch (e) {
        print('Error\n$e');
      }
    });
  }
}
