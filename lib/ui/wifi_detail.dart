import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vernet/api/isp_loader.dart';
import 'package:vernet/models/internet_provider.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/host_scan_page.dart';
import 'package:vernet/pages/ping_page.dart';
import 'package:vernet/pages/port_scan_page.dart';

import 'custom_tile.dart';

class WifiDetail extends StatefulWidget {
  const WifiDetail({Key? key}) : super(key: key);

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<WifiDetail> {
  WifiInfo? _wifiInfo;
  bool _location = false;

  _getWifiInfo() async {
    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    var wifiIP = await (NetworkInfo().getWifiIP());
    var wifiBSSID = await (NetworkInfo().getWifiBSSID());
    var wifiName = await (NetworkInfo().getWifiName());

    setState(() {
      _wifiInfo = WifiInfo(wifiIP, wifiBSSID, wifiName, wifiName == null);
    });
    if (Platform.isAndroid || Platform.isIOS) {
      Permission.location.serviceStatus.isEnabled.then((value) => setState(() {
            _location = value;
          }));
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
                ? CircularProgressIndicator.adaptive()
                : ListTile(
                    minVerticalPadding: 10,
                    leading: Icon(Icons.router),
                    title: Text('${_wifiInfo!.name}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connected to ${_wifiInfo!.bssid}'),
                        SizedBox(height: 5),
                        _location
                            ? SizedBox()
                            : Text(
                                'Location should be on to display Wifi name',
                                style: Theme.of(context)
                                    .textTheme
                                    .caption!
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                        Divider(height: 3),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HostScanPage(),
                              ),
                            );
                          },
                          child: Text('Scan for devices'),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: () {
                        _getWifiInfo();
                      },
                    ),
                  ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.network_check),
              title: Text('Network Troubleshooting'),
              minVerticalPadding: 10,
              subtitle: Column(
                children: [
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PingPage(),
                            ),
                          );
                        },
                        icon: Icon(Icons.trending_up),
                        label: Text('Ping'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PortScanPage(),
                            ),
                          );
                        },
                        icon: Icon(Icons.radar),
                        label: Text('Scan open ports'),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.signal_cellular_alt),
              title: Text('Internet Service Provider (ISP)'),
              subtitle: FutureBuilder<InternetProvider?>(
                future: ISPLoader().load(),
                builder: (BuildContext context,
                    AsyncSnapshot<InternetProvider?> snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTile(
                          leading: Icon(
                            Icons.public,
                            color: Theme.of(context).accentColor,
                          ),
                          child: Text('${snapshot.data!.ip}'),
                        ),
                        CustomTile(
                            leading: Icon(Icons.dns,
                                color: Theme.of(context).accentColor),
                            child: Text('${snapshot.data!.isp}')),
                        CustomTile(
                          leading: Icon(Icons.location_on,
                              color: Theme.of(context).accentColor),
                          child: Text(snapshot.data!.location.address),
                        ),
                        SizedBox(height: 5),
                        Divider(height: 3),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            _launchURL('https://fast.com');
                          },
                          icon: Icon(Icons.speed),
                          label: Text('Speed Test'),
                        )
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return Text("Unable to fetch ISP details");
                  }
                  return Text("Loading ISP details..");
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async =>
      await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
}
