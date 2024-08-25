import 'package:vernet/models/isar/device.dart';

abstract class ScannerService {
  Future<void> startNewScan(
    String subnet,
    String ip,
    String gatewayIp,
  );

  Future<Stream<List<Device>>> getOnGoingScan();
}
