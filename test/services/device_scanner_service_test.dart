import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';

void main() {
  test('DeviceScannerService can be instantiated', () {
    final service = DeviceScannerService();
    expect(service, isA<DeviceScannerService>());
  });
}
