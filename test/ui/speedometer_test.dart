import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/speedometer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeedometerWidget', () {
    test('constructor accepts correct parameters', () {
      const widget = SpeedometerWidget(
        currentSpeed: 42.0,
        rangeValues: RangeValues(0, 100),
        gradient: null,
      );

      expect(widget.currentSpeed, 42.0);
      expect(widget.rangeValues.start, 0);
      expect(widget.rangeValues.end, 100);
      expect(widget.gradient, isNull);
    });

    test('can be created with different speed values', () {
      const widget = SpeedometerWidget(
        currentSpeed: 75.5,
        rangeValues: RangeValues(0, 200),
        gradient: null,
      );

      expect(widget.currentSpeed, 75.5);
      expect(widget.rangeValues.end, 200);
    });

    test('can be created with gradient', () {
      const testGradient = LinearGradient(
        colors: [Colors.blue, Colors.purple],
      );

      const widget = SpeedometerWidget(
        currentSpeed: 50.0,
        rangeValues: RangeValues(0, 100),
        gradient: testGradient,
      );

      expect(widget.gradient, testGradient);
    });

    test('widget type is correct', () {
      const widget = SpeedometerWidget(
        currentSpeed: 50.0,
        rangeValues: RangeValues(0, 100),
        gradient: null,
      );

      expect(widget, isA<SpeedometerWidget>());
    });
  });
}
