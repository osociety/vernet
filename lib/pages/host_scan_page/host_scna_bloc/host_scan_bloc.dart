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
    on<StartNewScan>(_startNewScan);
  }

  /// Will contain all the hosts that got discovered in the network, will be use
  /// inorder to cancel on dispose of the page.
  Stream<ActiveHost>? hostsDiscoveredInNetwork;

  /// IP of the device in the local network.
  String? ip;

  /// Gateway IP of the current network
  late String? gatewayIp;

  /// List of all ActiveHost devices that got found in the current scan
  List<DeviceInTheNetwork> activeHostList = [];

  Future<void> _initialized(
    Initialized event,
    Emitter<HostScanState> emit,
  ) async {
    emit(const HostScanState.loadInProgress());
    ip = await NetworkInfo().getWifiIP();
    gatewayIp = await NetworkInfo().getWifiGatewayIP();

    add(const HostScanEvent.startNewScan());
  }

  Future<void> _startNewScan(
    StartNewScan event,
    Emitter<HostScanState> emit,
  ) async {
    final String subnet = ip!.substring(0, ip!.lastIndexOf('.'));
    activeHostList = [];

    hostsDiscoveredInNetwork = HostScanner.discover(
      subnet,
      firstSubnet: appSettings.firstSubnet,
      lastSubnet: appSettings.lastSubnet,
      resultsInIpAscendingOrder: false,
    );

    await for (final ActiveHost activeHostFound in hostsDiscoveredInNetwork!) {
      final DeviceInTheNetwork tempDeviceInTheNetwork =
          DeviceInTheNetwork.createWithAllNecessaryFields(
        ip: activeHostFound.ip,
        hostId: activeHostFound.hostId,
        make: activeHostFound.make,
        pingData: activeHostFound.pingData,
        currentDeviceIp: ip!,
        gatewayIp: gatewayIp!,
      );
      activeHostList.add(tempDeviceInTheNetwork);
      emit(HostScanState.foundNewDevice(activeHostList));
    }
    // emit(HostScanState.loadSuccess(activeHostList));
  }
}
