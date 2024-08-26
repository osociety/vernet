import 'package:isar/isar.dart';
part 'scan.g.dart';

@collection
class Scan {
  Scan({
    required this.gatewayIp,
    this.startTime,
    this.endTime,
    this.onGoing,
  });
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  final String gatewayIp;
  bool? onGoing;
  DateTime? startTime;
  DateTime? endTime;
}
