import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:speedometer/speedometer.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';

class SpeedTestDialog extends StatefulWidget {
  const SpeedTestDialog({
    super.key,
    required this.tester,
    required this.bestServersList,
  });
  final SpeedTestDart tester;
  final List<Server> bestServersList;

  @override
  State<SpeedTestDialog> createState() => _SpeedTestDialogState();
}

class _SpeedTestDialogState extends State<SpeedTestDialog> {
  final double _lowerValue = 100.0;
  final double _upperValue = 300.0;
  int start = 0;
  int end = 300;

  int counter = 0;

  final Duration _animationDuration = const Duration(milliseconds: 100);

  PublishSubject<double> eventObservable = PublishSubject();

  final rng = Random();
  bool speedTestStarted = false;
  bool downloadSpeedTestDone = false;
  bool uploadSpeedTestDone = false;
  static const int variance = 5;
  double currentDownloadSpeed = variance * 2;
  double progress = 0;
  int numberOfTests = 5;
  double currentUploadSpeed = variance * 2;
  late Timer timer;

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: const Text('Speed Test'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeedOMeter(
                start: start,
                end: end,
                highlightStart: _lowerValue / end,
                highlightEnd: _upperValue / end,
                themeData: Theme.of(context),
                eventObservable: eventObservable,
                animationDuration: _animationDuration,
              ),
              const SizedBox(height: 10),
              if (speedTestStarted)
                LinearProgressIndicator(
                  value: progress,
                )
              else
                const SizedBox(),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (downloadSpeedTestDone)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.download),
                          const SizedBox(width: 5),
                          Text('${currentDownloadSpeed.round()} Mbps'),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  const SizedBox(
                    width: 15,
                  ),
                  if (uploadSpeedTestDone)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.upload),
                          const SizedBox(width: 5),
                          Text('${currentUploadSpeed.round()} Mbps'),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        AdaptiveDialogAction(
          isDefaultAction: true,
          onPressed: speedTestStarted
              ? null
              : () {
                  setState(() {
                    speedTestStarted = true;
                  });
                  timer = Timer.periodic(
                    const Duration(milliseconds: 100),
                    (Timer t) => eventObservable.add(
                      currentDownloadSpeed -
                          variance +
                          Random().nextInt(variance) +
                          rng.nextDouble(),
                    ),
                  );
                  downloadSpeed(numberOfTests).listen((data) {
                    setState(() {
                      currentDownloadSpeed = data[0];
                      progress = data[1] / numberOfTests;
                    });
                  }).onDone(testUploadSpeed);
                },
          child: const Text('Start'),
        ),
      ],
    );
  }

  void testUploadSpeed() {
    setState(() {
      downloadSpeedTestDone = true;
      progress = 0;
    });
    uploadSpeed(numberOfTests).listen((data) {
      setState(() {
        currentUploadSpeed = data[0];
        progress = data[1] / numberOfTests;
      });
    }).onDone(() {
      eventObservable.add(0);
      timer.cancel();
      setState(() {
        speedTestStarted = false;
        uploadSpeedTestDone = true;
      });
    });
  }

  Stream<List<double>> downloadSpeed(int maxCount) async* {
    int i = 1;
    while (true) {
      i++;
      yield [
        await widget.tester.testDownloadSpeed(
          servers: widget.bestServersList,
        ),
        i.toDouble()
      ];
      if (i == maxCount + 1) break;
    }
  }

  Stream<List<double>> uploadSpeed(int maxCount) async* {
    int i = 1;
    while (true) {
      i++;
      yield [
        await widget.tester.testUploadSpeed(
          servers: widget.bestServersList,
        ),
        i.toDouble()
      ];
      if (i == maxCount + 1) break;
    }
  }
}
