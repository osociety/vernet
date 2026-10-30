import 'package:vernet/database/drift/drift_database.dart';

abstract class ScannerService {
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp, {
    void Function(double progress)? onProgress,
  });

  Future<Stream<List<DeviceData>>> getOnGoingScan();
}
