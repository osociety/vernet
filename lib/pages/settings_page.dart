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
              title: const Text('Dark Theme'),
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
              title: const Text(StringValue.firstSubnet),
              subtitle: const Text(StringValue.firstSubnetDesc),
              trailing: Text(
                '${appSettings.firstSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const FirstSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text(StringValue.lastSubnet),
              subtitle: const Text(StringValue.lastSubnetDesc),
              trailing: Text(
                '${appSettings.lastSubnet}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const LastSubnetDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text(StringValue.socketTimeout),
              subtitle: const Text(StringValue.socketTimeoutdesc),
              trailing: Text(
                '${appSettings.socketTimeout} ms',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const SocketTimeoutDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text(StringValue.pingCount),
              subtitle: const Text(StringValue.pingCountDesc),
              trailing: Text(
                '${appSettings.pingCount}',
                style: Theme.of(context)
                    .textTheme
                    .subtitle2
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const PingCountDialog(),
                );
                await appSettings.load();
                setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Check for Updates'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  checkForUpdates(context, showIfNoUpdate: true);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('About'),
              onTap: () async {
                final info = await PackageInfo.fromPlatform();
                showAboutDialog(
                  context: context,
                  applicationName: 'Vernet',
                  applicationVersion: '${info.version}+${info.buildNumber}',
                  applicationIcon: const Icon(Icons.radar),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('Report Issues'),
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
                      leading: const Icon(Icons.favorite),
                      title: const Text('Donate'),
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
                      leading: const Icon(Icons.code),
                      title: const Text('Source Code'),
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
                    const ListTile(
                      title: Text(
                        'Made with ❤️ in India',
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
  final String _issueUrl = '$_srcUrl/issues';
  final String _donateUrl = '$_srcUrl#support-and-donate';
  Future<void> _launchURL(String url) async =>
      await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
}
