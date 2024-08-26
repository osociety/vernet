import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';

AppSettings appSettings = AppSettings.instance;
Future<void> main() async {
  configureDependencies(Env.prod);

  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final appDocDirectory = await getApplicationDocumentsDirectory();
  await configureNetworkToolsFlutter(appDocDirectory.path);

  final bool allowed = await ConsentLoader.isConsentPageShown();
  await appSettings.load();

  runApp(MyApp(allowed));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  const MyApp(this.allowed, {super.key});

  final bool allowed;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();

  @override
  void initState() {
    super.initState();
    getCurrentAppTheme();
    startScanOnStartup();
  }

  Future<void> startScanOnStartup() async {
    if (appSettings.runScanOnStartup) {
      final ip = await NetworkInfo().getWifiIP();
      final gatewayIp = appSettings.customSubnet.isNotEmpty
          ? appSettings.customSubnet
          : await NetworkInfo().getWifiGatewayIP();
      final subnet = gatewayIp!.substring(0, gatewayIp.lastIndexOf('.'));
      getIt<DeviceScannerService>()
          .startNewScan(subnet, ip!, gatewayIp)
          .listen((device) {});
    }
  }

  Future<void> getCurrentAppTheme() async {
    themeChangeProvider.themePref =
        await themeChangeProvider.darkThemePreference.getTheme();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        return themeChangeProvider;
      },
      child: Consumer<DarkThemeProvider>(
        builder: (BuildContext context, value, Widget? child) {
          return MaterialApp(
            title: 'Vernet',
            theme: themeChangeProvider.darkTheme
                ? ThemeData.dark()
                : ThemeData.light(),
            home: widget.allowed
                ? const TabBarPage()
                : const LocationConsentPage(),
          );
        },
      ),
    );
  }
}

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<TabBarPage> {
  int _currentIndex = 0;
  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    checkForUpdates(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [const HomePage(), const SettingsPage()];
    return Scaffold(
      body: Container(
        padding: MediaQuery.of(context).padding,
        child: children[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped, // new
        currentIndex: _currentIndex, // new
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
