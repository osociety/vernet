import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/dark_theme_provider.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
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
    return SingleChildScrollView(
      child: Column(
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
              title: Text(StringValue.FIRST_SUBNET),
              subtitle: Text(StringValue.FIRST_SUBNET_DESC),
              trailing: Text(
                '${appSettings.firstSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).accentColor),
              ),
              onTap: () async {
                await showDialog(
                    context: context,
                    builder: (context) => FirstSubnetDialog());
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text(StringValue.LAST_SUBNET),
              subtitle: Text(StringValue.LAST_SUBNET_DESC),
              trailing: Text(
                '${appSettings.lastSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).accentColor),
              ),
              onTap: () async {
                await showDialog(
                    context: context, builder: (context) => LastSubnetDialog());
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text(StringValue.SOCKET_TIMEOUT),
              subtitle: Text(StringValue.SOCKET_TIMEOUT_DESC),
              trailing: Text(
                '${appSettings.socketTimeout} ms',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).accentColor),
              ),
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
              trailing: Text(
                '${appSettings.pingCount}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).accentColor),
              ),
              onTap: () async {
                await showDialog(
                    context: context, builder: (context) => PingCountDialog());
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Report Issues'),
              subtitle: Text(_issueUrl),
              onTap: () {
                _launchURL(_issueUrl);
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Donate'),
              subtitle: Text(_donateUrl),
              onTap: () {
                _launchURL(_donateUrl);
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Check for Updates'),
              trailing: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  checkForUpdates(context, showIfNoUpdate: true);
                },
              ),
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
            },
          ),
        ],
      ),
    );
  }

  String _issueUrl = 'https://github.com/git-elliot/vernet/issues';
  String _donateUrl = 'https://github.com/git-elliot/vernet#support-and-donate';
  void _launchURL(String url) async =>
      await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
}
