import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/strings.dart';

void main() {
  test('string constants are defined', () {
    expect(StringValue.firstSubnet, 'Start of device search');
    expect(StringValue.hostScanPageTitle, 'Find devices');
    expect(StringValue.ispPageTitle, 'Internet provider');
  });
}
