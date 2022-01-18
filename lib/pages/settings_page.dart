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
              title: Text('Check for Updates'),
              trailing: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  checkForUpdates(context, showIfNoUpdate: true);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('About'),
              onTap: () async {
                var info = await PackageInfo.fromPlatform();
                showAboutDialog(
                  context: context,
                  applicationName: 'Vernet',
                  applicationVersion: '${info.version}+${info.buildNumber}',
                  applicationIcon: Icon(Icons.radar),
                  children: [
                    ListTile(
                      leading: Icon(Icons.bug_report),
                      title: Text('Report Issues'),
                      // subtitle: Text(_issueUrl),
                      // trailing: IconButton(
                      //   icon: Icon(Icons.open_in_new),
                      //   onPressed: () {
                      //     _launchURL(_issueUrl);
                      //   },
                      // ),
                      onTap: () {
                        _launchURL(_issueUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.favorite),
                      title: Text('Donate'),
                      // subtitle: Text(_donateUrl),
                      // trailing: IconButton(
                      //   icon: Icon(Icons.open_in_new),
                      //   onPressed: () {
                      //     _launchURL(_donateUrl);
                      //   },
                      // ),
                      onTap: () {
                        _launchURL(_donateUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.code),
                      title: Text('Source Code'),
                      // subtitle: Text(_srcUrl),
                      onTap: () {
                        _launchURL(_srcUrl);
                      },

                      // trailing: IconButton(
                      //   icon: Icon(Icons.open_in_new),
                      //   onPressed: () {
                      //     _launchURL(_srcUrl);
                      //   },
                      // ),
                    ),
                    ListTile(
                      title: Text(
                        "Made with ❤️ in India",
                        textAlign: TextAlign.center,
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const String _srcUrl = 'https://github.com/git-elliot/vernet';
  String _issueUrl = '$_srcUrl/issues';
  String _donateUrl = '$_srcUrl#support-and-donate';
  void _launchURL(String url) async =>
      await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
}
