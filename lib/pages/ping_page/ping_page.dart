import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';

class PingPage extends StatefulWidget {
  const PingPage({super.key});

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends BasePage<PingPage> {
  final List<PingData> _pingPackets = [];
  Ping? _ping;
  PingSummary? _pingSummary;
  StreamSubscription<PingData>? _streamSubscription;

  @override
  String fieldLabel() {
    return 'Enter a domain or IP';
  }

  @override
  String title() {
    return 'Ping';
  }

  @override
  String buttonLabel() {
    return _ping == null ? 'Ping' : 'Stop';
  }

  @override
  Future<void> onPressed() async {
    _ping == null ? _startPinging() : _stop();
  }

  void _startPinging() {
    setState(() {
      _pingPackets.clear();
      _ping = Ping(
        textEditingController.text,
        count: appSettings.pingCount,
        forceCodepage: Platform.isWindows,
      );
    });
    _streamSubscription = _ping?.stream.listen(
      (event) {
        if (event.response != null) {
          setState(() {
            _pingPackets.add(event);
          });
        }

        if (event.summary != null) {
          setState(() {
            _pingSummary = event.summary;
          });
        }
      },
      onDone: _stop,
    );
  }

  void _stop() {
    try {
      _ping?.stop();
    } catch (e, stack) {
      debugPrintStack(stackTrace: stack);
    }
    setState(() {
      _ping = null;
    });
  }

  @override
  Widget buildResults(BuildContext context) {
    return Column(
      children: [
        AdaptiveListTile(title: _getPingSummary()),
        if (_pingPackets.isEmpty)
          const Center(
            child: Text('Ping results will appear here'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _pingPackets.length,
              itemBuilder: (context, index) {
                final PingResponse? response = _pingPackets[index].response;
                String? title = response?.ip ?? '';
                final String trailing = _getTime(response?.time);

                if (_pingPackets[index].error != null) {
                  title = _pingPackets[index].error.toString();
                }
                return Column(
                  children: [
                    AdaptiveListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 10.0, right: 10.0),
                      leading: Text('${response?.seq}'),
                      title: Text(title),
                      trailing: Text(trailing),
                    ),
                    const Divider(height: 4),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _getPingSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          key: WidgetKey.pingSummarySent.key,
          'Sent: ${_pingSummary?.transmitted ?? '--'}',
        ),
        Text(
          key: WidgetKey.pingSummaryReceived.key,
          'Received : ${_pingSummary?.transmitted ?? '--'}',
        ),
        Text(
          key: WidgetKey.pingSummaryTotalTime.key,
          'Total time: ${_getTime(_pingSummary?.time)}',
        ),
      ],
    );
  }

  String _getTime(Duration? time) {
    if (time != null) {
      final ms = time.inMicroseconds / Duration.millisecondsPerSecond;
      return '$ms ms';
    }
    return '--';
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription?.cancel();
  }
}
