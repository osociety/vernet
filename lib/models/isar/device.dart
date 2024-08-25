import 'package:isar/isar.dart';
part 'device.g.dart';

@collection
class Device {
  Device({
    required this.internetAddress,
    required this.macAddress,
    required this.make,
    required this.currentDeviceIp,
    required this.gatewayIp,
    required this.scanId,
  });
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  final int scanId;
  @Index(type: IndexType.value)
  final String internetAddress;
  final String currentDeviceIp;
  final String gatewayIp;
  final String macAddress;
  final String make;
}
