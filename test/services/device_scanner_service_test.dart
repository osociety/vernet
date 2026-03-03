import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceScannerService', () {
    test('can be constructed', () {
      final service = DeviceScannerService();
      expect(service, isA<DeviceScannerService>());
    });
  });
}

