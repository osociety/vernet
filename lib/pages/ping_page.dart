import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:vernet/main.dart';

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends State<PingPage> {
  List<PingData> _pingPackets = [];
  Ping? _ping;
  PingSummary? _pingSummary;
  StreamSubscription<PingData>? _streamSubscription;
  TextEditingController _textEditingController = TextEditingController();

  _startPinging() {
    setState(() {
      _pingPackets.clear();
      _ping = Ping(
        _textEditingController.text.toString(),
        count: appSettings.pingCount,
      );
    });
    _streamSubscription = _ping?.stream.listen((event) {
      // debugPrint('Running command: ${_ping?.command}');
      // print(event);
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
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
    _streamSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ping'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Container(
              margin: EdgeInsets.all(5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textEditingController,
                          decoration: InputDecoration(
                            filled: true,
                            hintText: 'Enter a domain or IP',
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 10.0),
                        child: ElevatedButton(
                          onPressed: _ping == null ? _startPinging : _stop,
                          child: Text(_ping == null ? 'Ping' : 'Stop'),
                        ),
                      ),
                    ],
                  ),
                  ListTile(subtitle: _getPingSummary()),
                ],
              ),
            ),
          ),
          Expanded(
            child: _pingPackets.isEmpty
                ? Center(
                    child: Text('Ping results will appear here'),
                  )
                : ListView.builder(
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

  _getTime(Duration? time) {
    if (time != null) {
      final ms = time.inMicroseconds / Duration.millisecondsPerSecond;
      return '$ms ms';
    }
    return '--';
  }
}
