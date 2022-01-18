import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:vernet/main.dart';

import '../base_page.dart';

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends BasePage<PingPage> {
  List<PingData> _pingPackets = [];
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
  void onPressed() async {
    _ping == null ? _startPinging() : _stop();
  }

  _startPinging() {
    setState(() {
      _pingPackets.clear();
      _ping = Ping(
        textEditingController.text.toString(),
        count: appSettings.pingCount,
      );
    });
    _streamSubscription = _ping?.stream.listen((event) {
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
    }, onDone: _stop);
  }

  _stop() {
    try {
      _ping?.stop();
    } catch (e) {
      print(e);
    }
    setState(() {
      _ping = null;
    });
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(
      child: Column(
        children: [
          ListTile(title: _getPingSummary()),
          _pingPackets.isEmpty
              ? Center(
                  child: Text('Ping results will appear here'),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: _pingPackets.length,
                    itemBuilder: (context, index) {
                      PingResponse? _response = _pingPackets[index].response;
                      String? title = _response?.ip ?? '';
                      String trailing = _getTime(_response?.time);

                      if (_pingPackets[index].error != null) {
                        title = _pingPackets[index].error.toString();
                        debugPrint('error is $title');
                      }
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding:
                                EdgeInsets.only(left: 10.0, right: 10.0),
                            leading: Text('${_response?.seq}'),
                            title: Text(title),
                            trailing: Text(trailing),
                          ),
                          Divider(height: 4),
                        ],
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _getPingSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Sent: ${_pingSummary?.transmitted ?? '--'}'),
        Text('Received : ${_pingSummary?.transmitted ?? '--'}'),
        Text('Total time: ${_getTime(_pingSummary?.time)}')
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
