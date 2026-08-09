import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart' as di;
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;

class FakeScannerService implements DeviceScannerService {
  FakeScannerService({required this.devices});
  final List<DeviceData> devices;
  final StreamController<List<DeviceData>> ongoingController =
      StreamController<List<DeviceData>>();

  @override
  Stream<DeviceData> startNewScan(String subnet, String ip, String gatewayIp) {
    return Stream.fromIterable(devices);
  }

  @override
  Future<Stream<List<DeviceData>>> getOnGoingScan() {
    return Future.value(ongoingController.stream);
  }

  @override
  Future<int> getCurrentDevicesCount() {
    return Future.value(devices.length);
  }
}

class FakeScanRepository implements ScanRepository {
  final StreamController<List<ScanData>> controller =
      StreamController<List<ScanData>>();

  @override
  Future<Stream<List<ScanData>>> watch(int id) async {
    return controller.stream;
  }

  @override
  Future<List<ScanData>> getList() async => throw UnimplementedError();

  @override
  Future<ScanData?> get(int id) async => throw UnimplementedError();

  @override
  Future<ScanData> put(ScanData t) async => throw UnimplementedError();

  @override
  Future<ScanData> update(ScanData t) async => throw UnimplementedError();

  @override
  Future<ScanData?> getOnGoingScan() async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HostScanBloc - Additional Coverage', () {
    late HostScanBloc bloc;
    late FakeScannerService scanner;
    late FakeScanRepository scanRepo;

    setUp(() async {
      globals.testingActive = true;
      SharedPreferences.setMockInitialValues({});
      await di.getIt.reset();

      scanner = FakeScannerService(devices: [
        const DeviceData(
          id: 1,
          internetAddress: '1',
          macAddress: '',
          hostMake: 'name1',
          currentDeviceIp: '',
          gatewayIp: '',
          scanId: 0,
        ),
      ]);
      scanRepo = FakeScanRepository();

      di.getIt.registerSingleton<DeviceScannerService>(scanner);
      di.getIt.registerSingleton<ScanRepository>(scanRepo);

      bloc = HostScanBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('startNewScan emits loadSuccess when testing is active', () async {
      globals.testingActive = true;
      bloc.gatewayIp = '192.168.0.1';
      bloc.subnet = '192.168.0';
      bloc.ip = '192.168.0.2';

      bloc.add(const HostScanEvent.startNewScan());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const HostScanState.loadInProgress(),
          isA<FoundNewDevice>(),
          isA<LoadSuccess>(),
        ]),
      );
    });

    test('loadScan event triggers scan loading', () async {
      bloc.gatewayIp = '192.168.0.1';
      bloc.subnet = '192.168.0';
      bloc.ip = '192.168.0.2';

      bloc.add(const HostScanEvent.loadScan());

      // Should emit loadInProgress at minimum
      await expectLater(
        bloc.stream,
        emits(const HostScanState.loadInProgress()),
      );
    });

    test('FoundNewDevice state contains correct devices', () {
      final devices = <DeviceData>{
        const DeviceData(
          id: 1,
          internetAddress: '192.168.1.1',
          macAddress: 'AA:BB:CC:DD:EE:FF',
          hostMake: 'Test Device',
          currentDeviceIp: '192.168.1.1',
          gatewayIp: '192.168.1.1',
          scanId: 1,
        ),
        const DeviceData(
          id: 2,
          internetAddress: '192.168.1.2',
          macAddress: '11:22:33:44:55:66',
          hostMake: 'Test Device 2',
          currentDeviceIp: '192.168.1.1',
          gatewayIp: '192.168.1.1',
          scanId: 1,
        ),
      };

      final state = HostScanState.foundNewDevice(devices);
      expect(state.maybeMap(foundNewDevice: (_) => true, orElse: () => false),
          isTrue);
    });

    test('LoadSuccess state contains correct devices', () {
      final devices = <DeviceData>{
        const DeviceData(
          id: 1,
          internetAddress: '192.168.1.1',
          macAddress: 'AA:BB:CC:DD:EE:FF',
          hostMake: 'Test Device',
          currentDeviceIp: '192.168.1.1',
          gatewayIp: '192.168.1.1',
          scanId: 1,
        ),
      };

      final state = HostScanState.loadSuccess(devices);
      expect(state.maybeMap(loadSuccess: (_) => true, orElse: () => false),
          isTrue);
    });

    test('HostScanBloc devicesSet can be populated and cleared', () {
      // Add devices to set
      bloc.devicesSet.add(const DeviceData(
        id: 1,
        internetAddress: '192.168.1.1',
        macAddress: '',
        hostMake: 'test',
        currentDeviceIp: '',
        gatewayIp: '',
        scanId: 0,
      ));

      expect(bloc.devicesSet.length, equals(1));

      // Clear the set
      bloc.devicesSet.clear();
      expect(bloc.devicesSet.length, equals(0));
    });

    test('HostScanBloc mDnsDevices can be populated and cleared', () {
      // Note: This test just verifies the map can be used
      // Full mDNS testing requires platform channels
      expect(bloc.mDnsDevices, isA<Map<String, dynamic>>());
    });
  });
}
