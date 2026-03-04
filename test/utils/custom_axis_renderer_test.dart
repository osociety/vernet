import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/utils/custom_axis_renderer.dart';

void main() {
  final renderer = CustomAxisRenderer();

  test('valueToFactor maps 0 to 0', () {
    expect(renderer.valueToFactor(0), closeTo(0.0, 1e-9));
  });

  test('valueToFactor maps 5 to 0.125', () {
    expect(renderer.valueToFactor(5), closeTo(0.125, 1e-9));
  });

  test('valueToFactor maps 10 to 0.25', () {
    expect(renderer.valueToFactor(10), closeTo(0.25, 1e-9));
  });

  test('valueToFactor maps 1000 to 1.0', () {
    expect(renderer.valueToFactor(1000), closeTo(1.0, 1e-9));
  });
}
