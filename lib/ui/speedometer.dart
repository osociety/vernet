import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:vernet/utils/custom_axis_renderer.dart';

class SpeedometerWidget extends StatelessWidget {
  const SpeedometerWidget(
      {super.key,
      required this.currentSpeed,
      required this.rangeValues,
      required this.gradient});

  final double currentSpeed;
  final RangeValues rangeValues;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      title: const GaugeTitle(text: 'Internet Speed Test'),
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          minimum: rangeValues.start,
          maximum: rangeValues.end,
          onCreateAxisRenderer: () {
            return CustomAxisRenderer();
          },
          canScaleToFit: true,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.1,
            thicknessUnit: GaugeSizeUnit.factor,
          ),
          pointers: <GaugePointer>[
            NeedlePointer(
              value: currentSpeed,
              enableAnimation: true,
            ),
            RangePointer(
              value: currentSpeed,
              enableAnimation: true,
              color: Colors.orange,
              gradient: gradient,
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              axisValue: rangeValues.start,
              angle: 90,
              positionFactor: 0.5,
              widget: Text(
                '${currentSpeed.floor()} Mbps',
              ),
            )
          ],
        ),
      ],
    );
  }
}
