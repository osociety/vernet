import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:latlong2/latlong.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/classes/settings.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
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
  Set<Device> devices = {};
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
        key: WidgetKey.runScanOnStartup.key,
        children: [
          Text(
            '${devices.length} devices ${scanRunning ? 'found' : 'connected'}',
          ),
          const SizedBox(width: 8),
          if (scanRunning)
            const AdaptiveCircularProgressIndicator()
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
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        const Divider(height: 3),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _getDeviceCountWidget(),
                            const SizedBox(width: 4),
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
                  return const Text("Unable to fetch WiFi details");
                } else {
                  return const Text('Loading...');
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
                        label: const Text('Ping'),
                      ),
                      const SizedBox(width: 10),
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
                        label: const Text('Lookup'),
                      ),
                      const SizedBox(width: 10),
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
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          child:
                                              Text(snapshot.data!.client.isp),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        RatingBar.builder(
                                          initialRating:
                                              snapshot.data!.client.ispRating,
                                          minRating: 1.0,
                                          itemSize: 25,
                                          glowColor: Colors.blue,
                                          allowHalfRating: true,
                                          ignoreGestures: true,
                                          itemPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4.0),
                                          itemBuilder: (context, _) =>
                                              const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                          ),
                                          onRatingUpdate: (rating) {},
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        Text(
                                            'Your ISP is rated ${snapshot.data!.client.ispRating} out of 5'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: SizedBox(
                                      height: 100,
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: LatLng(
                                            snapshot.data!.client.latitude,
                                            snapshot.data!.client.longitude,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.example.app',
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(
                                height: 5,
                              ),

                              const SizedBox(height: 5),
                              const Divider(height: 3),
                              const SizedBox(height: 10),

                              FutureBuilder<List<Server>?>(
                                future: tester.getBestServers(
                                    servers: snapshot.data!.servers),
                                builder: (BuildContext context,
                                    AsyncSnapshot<List<Server>?>
                                        serverSnapshot) {
                                  if (serverSnapshot.hasData &&
                                      serverSnapshot.data != null) {
                                    return Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  SpeedTestDialog(
                                                tester: tester,
                                                bestServersList:
                                                    serverSnapshot.data!,
                                                odometerStart: snapshot
                                                        .data!.odometer.start /
                                                    100000000,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.speed),
                                          label: const Text('Speed Test'),
                                        ),
                                      ],
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return const Text(
                                        'Unable to fetch ISP details');
                                  }
                                  return const Text('Loading ISP details..');
                                },
                              ),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [Text(StringValue.speedTestServer)],
                              ),
                              // ElevatedButton.icon(
                              //   onPressed: snapshot.data!.servers.isNotEmpty
                              //       ? () async {
                              //           await showDialog(
                              //             context: context,
                              //             builder: (context) => SpeedTestDialog(
                              //               tester: tester,
                              //               bestServersList:
                              //                   snapshot.data!.servers,
                              //               odometerStart:
                              //                   snapshot.data!.odometer.start /
                              //                       1000000000,
                              //             ),
                              //           );
                              //         }
                              //       : null,
                              //   icon: const Icon(Icons.speed),
                              //   label: const Text('Speed Test'),
                              // ),
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
