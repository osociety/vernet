import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';

class HostScanPage extends StatefulWidget {
  const HostScanPage({Key? key}) : super(key: key);

  @override
  _HostScanPageState createState() => _HostScanPageState();
}

class _HostScanPageState extends State<HostScanPage>
    with TickerProviderStateMixin {
  final Set<ActiveHost> _devices = {};
  double _progress = 0;
  bool _isScanning = false;
  StreamSubscription<ActiveHost>? _streamSubscription;

  Future<void> _getDevices() async {
    _devices.clear();
    final String? ip = await NetworkInfo().getWifiIP();
    if (ip != null && ip.isNotEmpty) {
      final String subnet = ip.substring(0, ip.lastIndexOf('.'));
      setState(() {
        _isScanning = true;
      });

      final stream = HostScanner.discover(
        subnet,
        firstSubnet: appSettings.firstSubnet,
        lastSubnet: appSettings.lastSubnet,
        progressCallback: (progress) {
          debugPrint('Progress : $progress');
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      _streamSubscription = stream.listen(
        (ActiveHost device) {
          debugPrint('Found device: ${device.ip}');
          setState(() {
            _devices.add(device);
          });
        },
        onDone: () {
          debugPrint('Scan completed');
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
      );
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
        title: const Text('Scan for Devices'),
        actions: [
          if (_isScanning)
            Container(
              margin: const EdgeInsets.only(right: 20.0),
              child: CircularPercentIndicator(
                radius: 20.0,
                lineWidth: 2.5,
                percent: _progress / 100,
                backgroundColor: Colors.grey,
                progressColor: Colors.white,
              ),
            )
          else
            IconButton(
              onPressed: _getDevices,
              icon: const Icon(Icons.refresh),
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
      return const Text(
        'No device found.\nTry changing first and last subnet in settings',
        textAlign: TextAlign.center,
      );
    } else if (_isScanning && _devices.isEmpty) {
      return const CircularProgressIndicator.adaptive();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final ActiveHost device =
                  SplayTreeSet.from(_devices).toList()[index] as ActiveHost;
              return ListTile(
                title: Text(device.make),
                subtitle: Text(device.ip),
                trailing: IconButton(
                  tooltip: 'Scan open ports for this target',
                  icon: const Icon(Icons.radar),
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
                    const SnackBar(
                      content: Text('IP copied to clipboard'),
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
