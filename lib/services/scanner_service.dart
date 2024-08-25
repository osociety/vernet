import 'package:vernet/models/isar/device.dart';

abstract class ScannerService {
  Stream<Device> startNewScan(
    String subnet,
    String ip,
    String gatewayIp,
  );

  Future<Stream<List<Device>>> getOnGoingScan();
}
