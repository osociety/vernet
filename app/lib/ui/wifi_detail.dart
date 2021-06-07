import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/pages/host_scan_page.dart';
import 'package:vernet/pages/ping_page.dart';
import 'package:vernet/pages/port_scan_page.dart';

class WifiDetail extends StatefulWidget {
  const WifiDetail({Key? key}) : super(key: key);

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<WifiDetail> {
  WifiInfo? _wifiInfo;
  bool _location = false;

  _getWifiInfo() async {
    await Permission.location.request();
    var wifiIP = await (NetworkInfo().getWifiIP());

    var wifiBSSID = await (NetworkInfo().getWifiBSSID());
    var wifiName = await (NetworkInfo().getWifiName());
    setState(() {
      _wifiInfo = WifiInfo(wifiIP, wifiBSSID, wifiName, wifiName == null);
    });
    Permission.location.serviceStatus.isEnabled.then((value) => setState(() {
          _location = value;
        }));
  }

  @override
  void initState() {
    super.initState();
    _getWifiInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: _wifiInfo == null
              ? CircularProgressIndicator.adaptive()
              : ListTile(
                  minVerticalPadding: 10,
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
      ],
    );
  }
}
