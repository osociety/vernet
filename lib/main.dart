import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/dark_theme_provider.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/settings_page.dart';

late AppSettings appSettings;
Future<void> main() async {
  configureDependencies(Env.prod);
  WidgetsFlutterBinding.ensureInitialized();
  final appDocDirectory = await getApplicationDocumentsDirectory();
  await configureNetworkTools(appDocDirectory.path, enableDebugging: true);
  final bool allowed = await ConsentLoader.isConsentPageShown();

  appSettings = AppSettings.instance..load();
  runApp(MyApp(allowed));
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
  }

  Future<void> getCurrentAppTheme() async {
    themeChangeProvider.darkTheme =
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
            title: 'Flutter Demo',
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
