import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';
import 'package:vernet/ui/speedometer.dart';
import 'package:vernet/values/strings.dart';

class SpeedTestDialog extends StatefulWidget {
  const SpeedTestDialog({
    super.key,
    required this.tester,
    required this.servers,
    required this.odometerStart,
  });
  final SpeedTestDart tester;
  final List<Server> servers;
  final double odometerStart;

  @override
  State<SpeedTestDialog> createState() => _SpeedTestDialogState();
}

// 0 5 10 50 100 250 500 750 1000
class _SpeedTestDialogState extends State<SpeedTestDialog> {
  final double _start = 0.0;
  final double _end = 1000.0;
  // Adjusted gradients for better clarity and accessibility
  final downloadGradient = const SweepGradient(
    colors: <Color>[Color(0xFF43EA6A), Color(0xFF1E90FF), Color(0xFFF80759)],
    stops: <double>[0.0, 0.5, 1.0],
  );
  final uploadGradient = const SweepGradient(
    colors: <Color>[Color(0xFFFFD700), Color(0xFF43EA6A), Color(0xFF1E90FF)],
    stops: <double>[0.0, 0.5, 1.0],
  );
  final rng = Random();
  static const int variance = 5;

  bool speedTestStarted = false;
  bool downloadSpeedTestDone = false;
  bool uploadSpeedTestDone = false;

  double currentSpeed = 0;
  double currentDownloadSpeed = variance * 2;
  double progress = 0;
  int numberOfTests = 4;
  double currentUploadSpeed = variance * 2;
  Timer? timer;
  List<Server>? bestServers;

  Future<List<Server>?> getBestServers() async {
    final result = await widget.tester.getBestServers(servers: widget.servers);
    result.sort((a, b) => a.latency.compareTo(b.latency));
    return result;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getBestServers().then((value) {
      setState(() {
        bestServers = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (bestServers != null && bestServers!.isNotEmpty) {
      return AdaptiveDialog(
        onClose: () {
          if (timer != null && timer!.isActive) {
            timer?.cancel();
          }
          Navigator.of(context).pop();
        },
        content: SizedBox(
          width: 400,
          height: 450,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeedometerWidget(
                currentSpeed: currentSpeed,
                rangeValues: RangeValues(_start, _end),
                gradient: speedTestStarted
                    ? downloadSpeedTestDone
                        ? uploadGradient
                        : downloadGradient
                    : null,
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (downloadSpeedTestDone)
                      Row(
                        children: [
                          const Icon(
                            Icons.download,
                            color: Color(
                                0xFF43EA6A), // Matches start of downloadGradient
                          ),
                          const SizedBox(width: 5),
                          Text('${currentDownloadSpeed.round()} Mbps'),
                        ],
                      )
                    else
                      const SizedBox(),
                    const SizedBox(
                      width: 15,
                    ),
                    if (uploadSpeedTestDone)
                      Row(
                        children: [
                          const Icon(
                            Icons.upload,
                            color: Color(
                                0xFFFFD700), // Matches start of uploadGradient
                          ),
                          const SizedBox(width: 5),
                          Text('${currentUploadSpeed.round()} Mbps'),
                        ],
                      )
                    else
                      const SizedBox(),
                  ],
                ),
              ),
              Text('Best server: ${bestServers!.first.name}'),
              Text('Latency: ${bestServers!.first.latency} ms'),
              const SizedBox(height: 5),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    StringValue.speedTestServer,
                    style: TextStyle(fontSize: 8),
                  )
                ],
              ),
            ],
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
                      downloadSpeedTestDone = false;
                      uploadSpeedTestDone = false;
                    });
                    currentDownloadSpeed = widget.odometerStart;
                    timer = Timer.periodic(
                      const Duration(milliseconds: 100),
                      (Timer t) => setState(() {
                        currentSpeed = currentDownloadSpeed -
                            variance +
                            Random().nextInt(variance) +
                            rng.nextDouble();
                      }),
                    );
                    downloadSpeed(numberOfTests, bestServers!).listen((data) {
                      setState(() {
                        currentDownloadSpeed = data[0];
                        progress = data[1] / numberOfTests;
                      });
                    }).onDone(() {
                      testUploadSpeed(bestServers!);
                    });
                  },
            child: Text(
              'Start',
              style: TextStyle(
                color: Theme.of(context).buttonTheme.colorScheme?.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return const AdaptiveDialog(
      title: Text('Loading Best Servers'),
      actions: [],
      content: Padding(
        padding: EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 50,
          width: 50,
          child: Center(
            child: AdaptiveCircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  void testUploadSpeed(List<Server> bestServerList) {
    setState(() {
      currentSpeed = 0;
    });

    timer?.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (Timer t) => setState(() {
        currentSpeed = currentUploadSpeed -
            variance +
            Random().nextInt(variance) +
            rng.nextDouble();
      }),
    );
    setState(() {
      downloadSpeedTestDone = true;
      progress = 0;
    });
    uploadSpeed(numberOfTests, bestServerList).listen((data) {
      setState(() {
        currentUploadSpeed = data[0];
        progress = data[1] / numberOfTests;
      });
    }).onDone(() {
      setState(() {
        currentSpeed = 0;
      });
      timer?.cancel();
      setState(() {
        speedTestStarted = false;
        uploadSpeedTestDone = true;
        progress = 0;
      });
    });
  }

  Stream<List<double>> downloadSpeed(
      int maxCount, List<Server> bestServerList) async* {
    int i = 1;
    while (true) {
      i++;
      yield [
        await widget.tester.testDownloadSpeed(
          servers: bestServerList,
        ),
        i.toDouble()
      ];
      if (i == maxCount + 1) break;
    }
  }

  Stream<List<double>> uploadSpeed(
      int maxCount, List<Server> bestServerList) async* {
    int i = 1;
    while (true) {
      i++;
      yield [
        await widget.tester.testUploadSpeed(
          servers: bestServerList,
        ),
        i.toDouble()
      ];
      if (i == maxCount + 1) break;
    }
  }
}
