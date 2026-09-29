import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speed_test_dart/classes/settings.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/isp_page/isp_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/custom_tile.dart';
import 'package:vernet/ui/speed_test_dialog.dart';
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
  Set<DeviceData> devices = {};
  SpeedTestDart tester = SpeedTestDart();

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
    String? wifiGatewayIP;
    try {
      wifiGatewayIP = await NetworkInfo().getWifiGatewayIP();
    } catch (e) {
      debugPrint('Unimplemented error $e');
    }
    final gatewayIp = appSettings.customSubnet.isNotEmpty
        ? appSettings.customSubnet
        : (wifiGatewayIP ?? wifiIP) ?? '';
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

    if (appSettings.runScanOnStartup && wifiIP != null) {
      getIt<DeviceScannerService>()
          .startNewScan(_wifiInfo!.subnet, wifiIP, gatewayIp)
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
    NotificationService.selectNotificationStream.stream.listen((
      String? payload,
    ) async {
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/hostscan', ModalRoute.withName('/'));
    });
  }

  @override
  void dispose() {
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
        key: WidgetKey.runScanOnStartup.key,
        children: [
          Text(
            '${devices.length} devices ${scanRunning ? 'found' : 'connected'}',
          ),
          const SizedBox(width: 8),
          if (scanRunning)
            const SizedBox(
              height: 30,
              width: 30,
              child: AdaptiveCircularProgressIndicator(),
            )
          else
            const SizedBox(),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildWifiFallback(BuildContext context) {
    return AdaptiveListTile(
      minVerticalPadding: 10,
      leading: const Icon(Icons.router),
      title: const Text(WifiInfo.noWifiName),
      subtitle: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _getDeviceCountWidget(),
          ElevatedButton(
            key: WidgetKey.scanForDevicesButton.key,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HostScanPage()),
              );
            },
            child: const Text(StringValue.hostScanPageTitle),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _getWifiInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: FutureBuilder<WifiInfo?>(
              future: _getWifiInfo(),
              initialData: WifiInfo(null, null, null, true, '', false),
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
                        Text('Connected through ${wifiInfo.bssid}'),
                        const SizedBox(height: 5),
                        if (wifiInfo.isLocationOn)
                          const SizedBox()
                        else
                          Text(
                            'Turn on location access to show the Wi-Fi name',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        const Divider(height: 3),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _getDeviceCountWidget(),
                            ElevatedButton(
                              key: WidgetKey.scanForDevicesButton.key,
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
                  return _buildWifiFallback(context);
                } else {
                  return _buildWifiFallback(context);
                }
              },
            ),
          ),
          Card(
            child: AdaptiveListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Check your connection'),
              minVerticalPadding: 10,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      ElevatedButton.icon(
                        key: WidgetKey.ping.key,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PingPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.trending_up),
                        label: const Text('Check a website'),
                      ),
                      ElevatedButton.icon(
                        key: WidgetKey.scanForOpenPortsButton.key,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PortScanPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.radar),
                        label: const Text('Find security gaps'),
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
              title: const Text('Website and address tools'),
              minVerticalPadding: 10,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      ElevatedButton.icon(
                        key: WidgetKey.dnsLookupButton.key,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DNSPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Find website addresses'),
                      ),
                      ElevatedButton.icon(
                        key: WidgetKey.reverseDnsLookupButton.key,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReverseDNSPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.find_replace),
                        label: const Text('Find a device name'),
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
              title: const Text('Your internet service'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appSettings.inAppInternet)
                    FutureBuilder<Settings?>(
                      future: tester
                          .getSettings(headers: {"User-Agent": "Mozilla/4.0"}),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<Settings?> snapshot,
                      ) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTile(
                                    leading: Icon(
                                      Icons.public,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    child: Text(snapshot.data!.client.ip),
                                  ),
                                  CustomTile(
                                    leading: Icon(
                                      Icons.dns,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    child: Text(snapshot.data!.client.isp),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              const SizedBox(height: 3),
                              const Divider(height: 3),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (context) => SpeedTestDialog(
                                          tester: tester,
                                          servers: snapshot.data!.servers,
                                          odometerStart:
                                              snapshot.data!.odometer.start /
                                                  100000000,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.speed),
                                    label: const Text('Test internet speed'),
                                  ),
                                  const SizedBox(width: 5),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => IspPage(
                                            tester: tester,
                                            settings: snapshot.data!,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.cloud_circle),
                                    label: const Text('See provider details'),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              const Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 4,
                                children: [Text(StringValue.speedTestServer)],
                              ),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          return const Text(
                              'Internet service details are not available right now');
                        }
                        return const Text('Loading ISP details..');
                      },
                    )
                  else
                    const Text('Internet access in the app is turned off'),
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
