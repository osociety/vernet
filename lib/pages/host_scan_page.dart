import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:vernet/main.dart';

import 'network_troubleshoot/port_scan_page.dart';

class HostScanPage extends StatefulWidget {
  const HostScanPage({Key? key}) : super(key: key);

  @override
  _HostScanPageState createState() => _HostScanPageState();
}

class _HostScanPageState extends State<HostScanPage>
    with TickerProviderStateMixin {
  Set<ActiveHost> _devices = {};
  double _progress = 0;
  StreamSubscription<ActiveHost>? _streamSubscription;

  void _getDevices() async {
    _devices.clear();
    final String? ip = await (NetworkInfo().getWifiIP());
    if (ip != null && ip.isNotEmpty) {
      final String subnet = ip.substring(0, ip.lastIndexOf('.'));
      final stream = HostScanner.discover(subnet,
          firstSubnet: appSettings.firstSubnet,
          lastSubnet: appSettings.lastSubnet, progressCallback: (progress) {
        debugPrint('Progress : $progress');
        if (this.mounted) {
          setState(() {
            _progress = progress;
          });
        }
      });

      _streamSubscription = stream.listen((ActiveHost device) {
        debugPrint('Found device: ${device.ip}');
        setState(() {
          _devices.add(device);
        });
      }, onDone: () {
        debugPrint('Scan completed');
        if (this.mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getDevices();
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan for Devices'),
        actions: [
          HostScanner.isScanning
              ? Container(
                  margin: EdgeInsets.only(right: 20.0),
                  child: new CircularPercentIndicator(
                    radius: 20.0,
                    lineWidth: 2.5,
                    percent: _progress / 100,
                    backgroundColor: Colors.grey,
                    progressColor: Colors.white,
                  ),
                )
              : IconButton(
                  onPressed: _getDevices,
                  icon: Icon(Icons.refresh),
                ),
        ],
      ),
      body: Center(
        child: buildListView(context),
      ),
    );
  }

  Widget buildListView(BuildContext context) {
    if (_progress >= 100 && _devices.isEmpty) {
      return Text(
        'No device found.\nTry changing first and last subnet in settings',
        textAlign: TextAlign.center,
      );
    } else if (HostScanner.isScanning && _devices.isEmpty) {
      return CircularProgressIndicator.adaptive();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              ActiveHost device = SplayTreeSet.from(_devices).toList()[index];
              return ListTile(
                title: Text(device.make),
                subtitle: Text(device.ip),
                trailing: IconButton(
                  tooltip: 'Scan open ports for this target',
                  icon: Icon(Icons.radar),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PortScanPage(target: device.ip),
                      ),
                    );
                  },
                ),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: device.ip));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("IP copied to clipboard"),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}
