import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
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
    activeHostList = await startSearchingDevices();
    emit(HostScanState.foundNewDevice(activeHostList));

    // emit(HostScanState.loadSuccess(activeHostList));
  }

  // TODO: can be improved by returning results from the isolate with a stream
  // TODO: and displaying them immediately for each new result.
  /// Will search devices in the network inside new isolate
  Future<List<DeviceInTheNetwork>> startSearchingDevices() async {
    return compute<List<String>, List<DeviceInTheNetwork>>(
      (params) async {
        final String subnetIsolate = params[0];
        final int firstSubnetIsolate = int.parse(params[1]);
        final int lastSubnetIsolate = int.parse(params[2]);
        final String currentDeviceIpIsolate = params[3];
        final String gatewayIpIsolate = params[4];

        final List<DeviceInTheNetwork> listOfDevicesTemp = [];

        /// Will contain all the hosts that got discovered in the network, will
        /// be use inorder to cancel on dispose of the page.
        final Stream<ActiveHost> hostsDiscoveredInNetwork =
            HostScanner.discover(
          subnetIsolate,
          firstSubnet: firstSubnetIsolate,
          lastSubnet: lastSubnetIsolate,
        );

        try {
          await for (final ActiveHost activeHostFound
              in hostsDiscoveredInNetwork) {
            final DeviceInTheNetwork tempDeviceInTheNetwork =
                DeviceInTheNetwork.createWithAllNecessaryFields(
              ip: activeHostFound.ip,
              hostId: activeHostFound.hostId,
              make: activeHostFound.make,
              pingData: activeHostFound.pingData,
              currentDeviceIp: currentDeviceIpIsolate,
              gatewayIp: gatewayIpIsolate,
            );
            listOfDevicesTemp.add(tempDeviceInTheNetwork);
          }
        } catch (e) {
          print('Error\n$e');
        }
        return listOfDevicesTemp;
      },
      [
        subnet!,
        appSettings.firstSubnet.toString(),
        appSettings.lastSubnet.toString(),
        ip!,
        gatewayIp!,
      ],
    );
  }
}
