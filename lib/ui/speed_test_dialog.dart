import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:speedometer/speedometer.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog_action.dart';
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
  List<Server>? bestServers;

  Future<List<Server>?> getBestServers() async {
    final result = await widget.tester.getBestServers(servers: widget.servers);
    result.sort((a, b) => a.latency.compareTo(b.latency));
    return result;
  }

  @override
  void initState() {
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
        title: const Text('Speed Test'),
        content: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height *
                      (Platform.isAndroid || Platform.isIOS ? 0.3 : 0.4),
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: SpeedOMeter(
                    start: start,
                    end: end,
                    highlightStart: _lowerValue / end,
                    highlightEnd: _upperValue / end,
                    themeData: Theme.of(context),
                    eventObservable: eventObservable,
                    animationDuration: _animationDuration,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (speedTestStarted)
                LinearProgressIndicator(
                  value: progress,
                )
              else
                const SizedBox(),
              const SizedBox(height: 5),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (downloadSpeedTestDone)
                      Row(
                        children: [
                          const Icon(Icons.download),
                          const SizedBox(width: 5),
                          Text('${currentDownloadSpeed.round()} Mbps'),
                        ],
                      )
                    else
                      const SizedBox(),
                    const SizedBox(
                      width: 5,
                    ),
                    if (uploadSpeedTestDone)
                      Row(
                        children: [
                          const Icon(Icons.upload),
                          const SizedBox(width: 5),
                          Text('${currentUploadSpeed.round()} Mbps'),
                        ],
                      )
                    else
                      const SizedBox(),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text('Best server: ${bestServers!.first.name}'),
              Text('Latency: ${bestServers!.first.latency} ms'),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text(StringValue.speedTestServer)],
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
                      (Timer t) => eventObservable.add(
                        currentDownloadSpeed -
                            variance +
                            Random().nextInt(variance) +
                            rng.nextDouble(),
                      ),
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
            child: const Text('Start'),
          ),
        ],
      );
    }

    return const AdaptiveDialog(
      title: Text('Loading Best Servers'),
      actions: [],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Center(
              child: AdaptiveCircularProgressIndicator(),
            ),
          )
        ],
      ),
    );
  }

  void testUploadSpeed(List<Server> bestServerList) {
    eventObservable.add(0);
    timer.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (Timer t) => eventObservable.add(
        currentUploadSpeed -
            variance +
            Random().nextInt(variance) +
            rng.nextDouble(),
      ),
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
      eventObservable.add(0);
      timer.cancel();
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
