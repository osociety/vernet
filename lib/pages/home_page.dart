import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/api/isp_loader.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/providers/internet_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/custom_tile.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<HomePage> {
  WifiInfo? _wifiInfo;
  bool scanRunning = false;
  Set<Device> devices = {};

  Future<WifiInfo?> _getWifiInfo() async {
    if (_wifiInfo != null) {
      return _wifiInfo;
    }
    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    final wifiIP = await NetworkInfo().getWifiIP();
    final wifiBSSID = await NetworkInfo().getWifiBSSID();
    final wifiName = await NetworkInfo().getWifiName();
    final gatewayIp = appSettings.customSubnet.isNotEmpty
        ? appSettings.customSubnet
        : await NetworkInfo().getWifiGatewayIP() ?? '';
    final bool isLocationOn = (Platform.isAndroid || Platform.isIOS) &&
        await Permission.location.serviceStatus.isEnabled;
    _wifiInfo = WifiInfo(
      wifiIP,
      wifiBSSID,
      wifiName,
      wifiName == null,
      gatewayIp,
      isLocationOn,
    );

    if (appSettings.runScanOnStartup) {
      getIt<DeviceScannerService>()
          .startNewScan(_wifiInfo!.subnet, wifiIP!, gatewayIp)
          .listen((device) {
        if (mounted) {
          setState(() {
            scanRunning = true;
            devices.add(device);
          });
        }
      }).onDone(() async {
        if (mounted) {
          setState(() {
            scanRunning = false;
          });
        }
        await NotificationService.showNotificationWithActions();
      });
    }

    return _wifiInfo;
  }

  void _configureSelectNotificationSubject() {
    NotificationService.selectNotificationStream.stream
        .listen((String? payload) async {
      await Navigator.of(context).pushNamedAndRemoveUntil(
        '/hostscan',
        ModalRoute.withName('/'),
      );
    });
  }

  @override
  void dispose() {
    NotificationService.selectNotificationStream.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _configureSelectNotificationSubject();
  }

  Widget _getDeviceCountWidget() {
    if (appSettings.runScanOnStartup) {
      return Row(
        children: [
          Text(
            '${devices.length} devices ${scanRunning ? 'found' : 'connected'}',
          ),
          const SizedBox(
            width: 8,
          ),
          if (scanRunning)
            const CircularProgressIndicator.adaptive()
          else
            const SizedBox(),
        ],
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: FutureBuilder<WifiInfo?>(
              future: _getWifiInfo(),
              builder: (
                BuildContext context,
                AsyncSnapshot<WifiInfo?> snapshot,
              ) {
                if (snapshot.hasData && snapshot.data != null) {
                  final wifiInfo = snapshot.data;
                  return AdaptiveListTile(
                    minVerticalPadding: 10,
                    leading: const Icon(Icons.router),
                    title: Text(wifiInfo!.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connected to ${wifiInfo.bssid}'),
                        const SizedBox(height: 5),
                        if (wifiInfo.isLocationOn)
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
                        Row(
                          children: [
                            _getDeviceCountWidget(),
                            const SizedBox(
                              width: 4,
                            ),
                            ElevatedButton(
                              key: Keys.scanForDevicesButton,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HostScanPage(),
                                  ),
                                );
                              },
                              child: const Text(StringValue.hostScanPageTitle),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _getWifiInfo();
                      },
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Text("Unable to fetch WiFi details");
                } else {
                  return const CircularProgressIndicator.adaptive();
                }
              },
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
