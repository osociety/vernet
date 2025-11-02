import 'package:syncfusion_flutter_gauges/gauges.dart';

class CustomAxisRenderer extends RadialAxisRenderer {
  CustomAxisRenderer() : super();

  /// Generated the 9 non-linear interval labels from 0 to 1000
  /// instead of actual generated labels.
  @override
  List<CircularAxisLabel> generateVisibleLabels() {
    final List<CircularAxisLabel> visibleLabels = <CircularAxisLabel>[];
    for (num i = 0; i < 9; i++) {
      final double value = _calculateLabelValue(i);
      final CircularAxisLabel label = CircularAxisLabel(
          axis.axisLabelStyle, value.toInt().toString(), i, false);
      label.value = value;
      visibleLabels.add(label);
    }

    return visibleLabels;
  }

  /// Returns the factor(0 to 1) from value to place the labels in an axis.
  @override
  double valueToFactor(double value) {
    // Segments: [0-5],[5-10],[10-50],[50-100],[100-250],[250-500],[500-750],[750-1000]
    if (value >= 0 && value <= 5) {
      return (value * 0.125) / 5;
    } else if (value > 5 && value <= 10) {
      return (((value - 5) * 0.125) / (10 - 5)) + (1 * 0.125);
    } else if (value > 10 && value <= 50) {
      return (((value - 10) * 0.125) / (50 - 10)) + (2 * 0.125);
    } else if (value > 50 && value <= 100) {
      return (((value - 50) * 0.125) / (100 - 50)) + (3 * 0.125);
    } else if (value > 100 && value <= 250) {
      return (((value - 100) * 0.125) / (250 - 100)) + (4 * 0.125);
    } else if (value > 250 && value <= 500) {
      return (((value - 250) * 0.125) / (500 - 250)) + (5 * 0.125);
    } else if (value > 500 && value <= 750) {
      return (((value - 500) * 0.125) / (750 - 500)) + (6 * 0.125);
    } else if (value > 750 && value <= 1000) {
      return (((value - 750) * 0.125) / (1000 - 750)) + (7 * 0.125);
    } else {
      return 1;
    }
  }

  /// To return the label value based on interval
  double _calculateLabelValue(num value) {
    // indices: 0..8 -> 0,5,10,50,100,250,500,750,1000
    if (value == 0) {
      return 0;
    } else if (value == 1) {
      return 5;
    } else if (value == 2) {
      return 10;
    } else if (value == 3) {
      return 50;
    } else if (value == 4) {
      return 100;
    } else if (value == 5) {
      return 250;
    } else if (value == 6) {
      return 500;
    } else if (value == 7) {
      return 750;
    } else {
      return 1000;
    }
  }
}
