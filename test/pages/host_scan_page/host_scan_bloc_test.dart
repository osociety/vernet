import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart' as di;
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;

/// A simple fake implementation of [DeviceScannerService] that emits
/// a predetermined list of devices and allows callers to supply an
/// ongoing-scan stream.
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
  Future<Stream<List<DeviceData>>> getOnGoingScan() async {
    return ongoingController.stream;
  }

  @override
  Future<int> getCurrentDevicesCount() async {
    return devices.length;
  }
}

/// A fake [ScanRepository] that returns a stream of scan lists which
/// can be pushed via [controller].
class FakeScanRepository implements ScanRepository {
  final StreamController<List<ScanData>> controller =
      StreamController<List<ScanData>>();

  @override
  Future<Stream<List<ScanData>>> watch(int id) async {
    return controller.stream;
  }

  // other methods are not used in these tests
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

  group('HostScanBloc', () {
    late HostScanBloc bloc;
    late FakeScannerService scanner;
    late FakeScanRepository scanRepo;

    setUp(() async {
      globals.testingActive = true;
      // reset the service locator between tests; await to ensure it completes
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
        const DeviceData(
          id: 2,
          internetAddress: '2',
          macAddress: '',
          hostMake: 'name2',
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

    test('initial state is HostScanState.initial', () {
      expect(bloc.state, equals(HostScanState.initial()));
    });

    test('startNewScan event emits expected states', () async {
      // ensure required fields are initialized to avoid runtime errors
      bloc.gatewayIp = '192.168.0.1';
      bloc.subnet = '192.168.0';
      bloc.ip = '192.168.0.2';

      // first send the event, then wait for the expected sequence
      bloc.add(const HostScanEvent.startNewScan());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const HostScanState.loadInProgress(),
          isA<FoundNewDevice>(),
          const HostScanState.loadInProgress(),
          isA<FoundNewDevice>(),
          isA<LoadSuccess>(),
        ]),
      );
    });

    test(
        'loadScan event listens to ongoing scan and completes when repo reports done',
        () async {
      // mock shared preferences to avoid MissingPluginException and provide a scan id
      SharedPreferences.setMockInitialValues({'CurrentScanIDKey': 1});

      final collected = <HostScanState>[];
      final sub = bloc.stream.listen((s) {
        collected.add(s);
      });

      bloc.add(const HostScanEvent.loadScan());

      // schedule devices and completion after event
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        scanner.ongoingController.add([
          const DeviceData(
            id: 3,
            internetAddress: 'foo',
            macAddress: '',
            hostMake: 'bar',
            currentDeviceIp: '',
            gatewayIp: '',
            scanId: 0,
          ),
        ]);
      });

      Future<void>.delayed(const Duration(milliseconds: 30), () {
        scanRepo.controller.add([
          ScanData(
            id: 1,
            gatewayIp: '192.168.0',
            startTime: DateTime.now(),
            onGoing: false,
          ),
        ]);
      });

      // give the bloc some time to process all asynchronous updates
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // expecting at least one progress, a device found, and eventual success
      expect(collected, isNotEmpty);
      expect(collected.any((s) => s is FoundNewDevice), isTrue);
      expect(collected.any((s) => s is LoadSuccess), isTrue);

      await sub.cancel();
    });
  });
}
