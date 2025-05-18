import 'package:vernet/database/drift/drift_database.dart';

abstract class ScannerService {
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp,
  );

  Future<Stream<List<DeviceData>>> getOnGoingScan();
}
