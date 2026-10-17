import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';

typedef PingFactory = Ping Function(
  String host, {
  int? count,
  bool forceCodepage,
});

class PingPage extends StatefulWidget {
  const PingPage({
    super.key,
    this.target = '',
    this.autostart = false,
    this.pingBuilder,
  });

  final String target;
  final bool autostart;
  final PingFactory? pingBuilder;

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends BasePage<PingPage> {
  final List<PingEvent> _pingPackets = [];
  Ping? _ping;
  PingSummary? _pingSummary;
  RoundTripStats? _stats;
  StreamSubscription<PingEvent>? _streamSubscription;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    if (widget.target.isNotEmpty) {
      textEditingController.text = widget.target;
      if (widget.autostart) {
        Future.delayed(Durations.short2, _startPinging);
      }
    }
  }

  @override
  String fieldLabel() {
    return 'Enter a website or device address';
  }

  @override
  String title() {
    return 'Check connection';
  }

  @override
  String buttonLabel() {
    return _ping == null ? 'Start check' : 'Stop';
  }

  @override
  Future<void> onPressed() async {
    _ping == null ? _startPinging() : _stop();
  }

  void _startPinging() {
    final factory = widget.pingBuilder ??
        ((host, {count, forceCodepage = false}) => Ping(
              host,
              count: count,
              forceCodepage: forceCodepage,
            ));
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _pingPackets.clear();
      _pingSummary = null;
      _stats = null;
      _ping = factory(
        textEditingController.text,
        count: appSettings.pingCount,
        forceCodepage: Platform.isWindows,
      );
    });
    _streamSubscription = _ping?.stream.listen(
      (event) {
        if (event is PingSummary) {
          _stopwatch.stop();
          setState(() {
            _pingSummary = event;
            _stats = event.stats ?? _stats;
          });
        } else {
          setState(() {
            _pingPackets.add(event);
            _stats = event.stats ?? _stats;
          });
        }
      },
      onDone: _stop,
    );
  }

  void _stop() {
    _stopwatch.stop();
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
            child: Text('Connection results will appear here'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _pingPackets.length,
              itemBuilder: (context, index) {
                final PingEvent packet = _pingPackets[index];
                String? leading;
                String title = '';
                final String trailing;

                if (packet is PingResponse) {
                  leading = packet.seq != null ? '${packet.seq}' : null;
                  title = packet.ip ?? '';
                  trailing = _getTime(packet.time);
                } else if (packet is PingError) {
                  leading = packet.seq != null ? '${packet.seq}' : null;
                  title = packet.message ?? packet.error.name;
                  trailing = '--';
                } else {
                  trailing = '--';
                }
                return Column(
                  children: [
                    AdaptiveListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 10.0, right: 10.0),
                      leading: leading != null ? Text(leading) : null,
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
    final stats = _pingSummary?.stats ?? _stats;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          key: WidgetKey.pingSummarySent.key,
          'Checks sent: ${_pingSummary?.transmitted ?? '--'}',
        ),
        Text(
          key: WidgetKey.pingSummaryReceived.key,
          'Replies received: ${_pingSummary?.received ?? '--'}',
        ),
        Text(
          key: WidgetKey.pingSummaryPacketLoss.key,
          'Packet loss: ${_getPacketLoss()}',
        ),
        Text(
          key: WidgetKey.pingSummaryTotalTime.key,
          'Total time: ${_getTime(_totalTime)}',
        ),
        Text(
          key: WidgetKey.pingSummaryMin.key,
          'Min: ${_getTime(stats?.min)}',
        ),
        Text(
          key: WidgetKey.pingSummaryAvg.key,
          'Avg: ${_getTime(stats?.avg)}',
        ),
        Text(
          key: WidgetKey.pingSummaryMax.key,
          'Max: ${_getTime(stats?.max)}',
        ),
        Text(
          key: WidgetKey.pingSummaryStdDev.key,
          'Std dev: ${_getTime(stats?.stddev)}',
        ),
      ],
    );
  }

  Duration? get _totalTime {
    if (_pingSummary?.time != null) {
      return _pingSummary!.time;
    }
    if (_stopwatch.elapsedMilliseconds > 0 &&
        (_pingSummary != null || _ping == null)) {
      return _stopwatch.elapsed;
    }
    return null;
  }

  String _getPacketLoss() {
    if (_pingSummary != null) {
      final loss = _pingSummary!.packetLoss;
      return '${loss.toStringAsFixed(loss.truncateToDouble() == loss ? 0 : 1)}%';
    }
    return '--';
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
    _streamSubscription?.cancel();
    _ping?.stop();
    super.dispose();
  }
}
