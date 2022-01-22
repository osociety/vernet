import 'dart:async';
import 'dart:collection';
import 'dart:io';

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
  final Set<ActiveHost> _hosts = {};
  double _progress = 0;
  bool _isScanning = false;
  StreamSubscription<ActiveHost>? _streamSubscription;
  late String? _ip;
  late String? _gatewayIP;

  Future<void> _getDevices() async {
    _hosts.clear();
    _ip = await NetworkInfo().getWifiIP();
    _gatewayIP = await NetworkInfo().getWifiGatewayIP();

    if (_ip != null && _ip!.isNotEmpty) {
      final String subnet = _ip!.substring(0, _ip!.lastIndexOf('.'));
      setState(() {
        _isScanning = true;
      });

      final stream = HostScanner.discover(
        subnet,
        firstSubnet: appSettings.firstSubnet,
        lastSubnet: appSettings.lastSubnet,
        progressCallback: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      _streamSubscription = stream.listen(
        (ActiveHost host) {
          debugPrint('Found host: ${host.ip}');
          setState(() {
            _hosts.add(host);
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
    if (_progress >= 100 && _hosts.isEmpty) {
      return const Text(
        'No host found.\nTry changing first and last subnet in settings',
        textAlign: TextAlign.center,
      );
    } else if (_isScanning && _hosts.isEmpty) {
      return const CircularProgressIndicator.adaptive();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _hosts.length,
            itemBuilder: (context, index) {
              final ActiveHost host =
                  SplayTreeSet.from(_hosts).toList()[index] as ActiveHost;
              return ListTile(
                leading: _getHostIcon(host.ip),
                title: Text(_getDeviceMake(host)),
                subtitle: Text(host.ip),
                trailing: IconButton(
                  tooltip: 'Scan open ports for this target',
                  icon: const Icon(Icons.radar),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PortScanPage(target: host.ip),
                      ),
                    );
                  },
                ),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: host.ip));
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

  String _getDeviceMake(ActiveHost host) {
    if (_ip == host.ip) {
      return 'This device';
    } else if (_gatewayIP == host.ip) {
      return 'Router/Gateway';
    }
    return host.make;
  }

  Icon _getHostIcon(String hostIp) {
    if (hostIp == _ip) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icon(Icons.computer);
      }
      return Icon(Icons.smartphone);
    } else if (hostIp == _gatewayIP) {
      return Icon(Icons.router);
    }
    return Icon(Icons.devices);
  }
}
