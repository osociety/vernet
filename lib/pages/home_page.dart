import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/api/isp_loader.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/internet_provider.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/custom_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<HomePage> {
  WifiInfo? _wifiInfo;
  bool _location = false;

  Future<void> _getWifiInfo() async {
    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    final wifiIP = await NetworkInfo().getWifiIP();
    final wifiBSSID = await NetworkInfo().getWifiBSSID();
    final wifiName = await NetworkInfo().getWifiName();

    setState(() {
      _wifiInfo = WifiInfo(wifiIP, wifiBSSID, wifiName, wifiName == null);
    });
    if (Platform.isAndroid || Platform.isIOS) {
      Permission.location.serviceStatus.isEnabled.then(
        (value) => setState(() {
          _location = value;
        }),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getWifiInfo();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: _wifiInfo == null
                ? const CircularProgressIndicator.adaptive()
                : AdaptiveListTile(
                    minVerticalPadding: 10,
                    leading: const Icon(Icons.router),
                    title: Text(_wifiInfo!.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connected to ${_wifiInfo!.bssid}'),
                        const SizedBox(height: 5),
                        if (_location)
                          const SizedBox()
                        else
                          Text(
                            'Location should be on to display Wifi name',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        const Divider(height: 3),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HostScanPage(),
                              ),
                            );
                          },
                          child: const Text('Scan for devices'),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _getWifiInfo();
                      },
                    ),
                  ),
          ),
          Card(
            child: AdaptiveListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Network Troubleshooting'),
              minVerticalPadding: 10,
              subtitle: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PingPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.trending_up),
                        label: const Text('Ping'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PortScanPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.radar),
                        label: const Text('Scan open ports'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              leading: const Icon(Icons.dns),
              title: const Text('Domain Name System (DNS)'),
              minVerticalPadding: 10,
              subtitle: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DNSPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Lookup'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReverseDNSPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.find_replace),
                        label: const Text('Reverse Lookup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: AdaptiveListTile(
              leading: const Icon(Icons.signal_cellular_alt),
              title: const Text('Internet Service Provider (ISP)'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appSettings.inAppInternet)
                    FutureBuilder<InternetProvider?>(
                      future: ISPLoader().load(),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<InternetProvider?> snapshot,
                      ) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTile(
                                leading: Icon(
                                  Icons.public,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                child: Text(snapshot.data!.ip),
                              ),
                              CustomTile(
                                leading: Icon(
                                  Icons.dns,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                child: Text(snapshot.data!.isp),
                              ),
                              CustomTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                child: Text(snapshot.data!.location.address),
                              ),
                              const SizedBox(height: 5),
                              const Divider(height: 3),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          return const Text('Unable to fetch ISP details');
                        }
                        return const Text('Loading ISP details..');
                      },
                    )
                  else
                    const Text("In-App Internet is off"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      launchURLWithWarning(context, 'https://fast.com');
                    },
                    icon: const Icon(Icons.speed),
                    label: const Text('Speed Test'),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
