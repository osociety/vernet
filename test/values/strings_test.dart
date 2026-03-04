import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/strings.dart';

void main() {
  test('string constants are defined', () {
    expect(StringValue.firstSubnet, 'First Subnet');
    expect(StringValue.hostScanPageTitle, 'Scan');
    expect(StringValue.ispPageTitle, 'Internet Service Provider');
  });
}
