import 'package:injectable/injectable.dart';
import 'package:isar/isar.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/repository/repository.dart';
import 'package:vernet/services/database_service.dart';

@Injectable()
class DeviceRepository extends IsarRepository<Device> {
  DeviceRepository(this._database);
  final DatabaseService _database;

  @override
  Future<Device?> get(Id id) async {
    final deviceDB = await _database.open();
    return deviceDB!.devices.get(id);
  }

  @override
  Future<List<Device>> getList() async {
    final deviceDB = await _database.open();
    return deviceDB!.devices.where().findAll();
  }

  @override
  Future<Device> put(Device device) async {
    final deviceDB = await _database.open();
    await deviceDB!.writeTxn(() async {
      await deviceDB.devices.put(device);
    });
    return device;
  }

  Future<Device?> getDevice(int scanId, String address) async {
    final deviceDB = await _database.open();
    return deviceDB!.devices
        .filter()
        .scanIdEqualTo(scanId)
        .and()
        .internetAddressEqualTo(address)
        .findFirst();
  }

  Future<Stream<List<Device>>> watch(int scanId) async {
    final deviceDB = await _database.open();
    return deviceDB!.devices
        .filter()
        .scanIdEqualTo(scanId)
        .sortByInternetAddress()
        .build()
        .watch(fireImmediately: true);
  }
}
