import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/dark_theme_provider.dart';
import 'package:vernet/ui/settings_dialog/max_host_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/values/strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Column(
      children: [
        Card(
          child: ListTile(
            title: Text("Dark Theme"),
            trailing: Switch(
              value: themeChange.darkTheme,
              onChanged: (bool? value) {
                themeChange.darkTheme = value ?? false;
              },
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text(StringValue.MAX_HOST_SIZE),
            subtitle: Text(StringValue.MAX_HOST_SIZE_DESC),
            trailing: Text('${appSettings.maxNetworkSize} hosts'),
            onTap: () async {
              await showDialog(
                  context: context, builder: (context) => MaxHostDialog());
              await appSettings.load();
              setState(() {});
            },
          ),
        ),
        Card(
          child: ListTile(
            title: Text(StringValue.SOCKET_TIMEOUT),
            subtitle: Text(StringValue.SOCKET_TIMEOUT_DESC),
            trailing: Text('${appSettings.socketTimeout} ms'),
            onTap: () async {
              await showDialog(
                  context: context,
                  builder: (context) => SocketTimeoutDialog());
              await appSettings.load();
              setState(() {});
            },
          ),
        ),
        Card(
          child: ListTile(
            title: Text(StringValue.PING_COUNT),
            subtitle: Text(StringValue.PING_COUNT_DESC),
            trailing: Text('${appSettings.pingCount}'),
            onTap: () async {
              await showDialog(
                  context: context, builder: (context) => PingCountDialog());
              await appSettings.load();
              setState(() {});
            },
          ),
        ),
        SizedBox(height: 10),
        Text("Made with ❤️ in India"),
        SizedBox(height: 10),
        FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder:
                (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
              if (snapshot.hasData) {
                return Text(
                    'Version : ${snapshot.data?.version}+${snapshot.data?.buildNumber}');
              }
              return SizedBox();
            }),
      ],
    );
  }
}
