import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:speed_test_dart/classes/settings.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/isp_page/isp_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/neighbor_discovery_page/neighbor_discovery_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/pages/subnet_calculator_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/isp_lookup_service.dart';
import 'package:vernet/values/globals.dart' as globals;

AppSettings appSettings = AppSettings.instance;
Future<void> main() async {
  configureDependencies(Env.prod);

  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  try {
    final appDocDirectory = await getApplicationDocumentsDirectory();
    await configureNetworkToolsFlutter(appDocDirectory.path, rebuildData: true);
  } catch (e, st) {
    debugPrint('Network tools init failed: $e\n$st');
  }

  final bool allowed = await ConsentLoader.isConsentPageShown();
  await appSettings.load();

  await NotificationService.initNotification();

  runApp(MyApp(allowed));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  const MyApp(this.allowed, {super.key, this.testing = false});
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  // static const Color mainColor = Colors.deepPurple;

  final bool allowed;
  final bool testing;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  StreamSubscription<String?>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.testing) globals.testingActive = true;
    if (!globals.testingActive) {
      NotificationService.grantPermissions();
    }
    _notificationTapSubscription =
        NotificationService.selectNotificationStream.stream
            .listen(_openScanFromNotification);
    getCurrentAppTheme();
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _openScanFromNotification(String? payload) {
    if (payload != NotificationService.hostScanPayload) {
      return;
    }
    MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/hostscan',
      ModalRoute.withName('/'),
    );
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
            navigatorKey: MyApp.navigatorKey,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                    builder: (context) => homePage,
                  );

                case '/hostscan':
                  return MaterialPageRoute(
                    builder: (context) {
                      return HostScanPage();
                    },
                  );

                default:
                  assert(false, 'Page ${settings.name} not found');
                  return null;
              }
            },
            title: 'Vernet',
            theme: themeChangeProvider.darkTheme
                ? ThemeData.dark()
                : ThemeData.light(),
            home: homePage,
          );
        },
      ),
    );
  }

  Widget get homePage =>
      widget.allowed ? const TabBarPage() : const LocationConsentPage();
}

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<TabBarPage> {
  static const double _largeLayoutBreakpoint = 600;
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _sidebarController;

  @override
  void initState() {
    super.initState();
    _sidebarController = SidebarXController(selectedIndex: 0, extended: true);
    checkForUpdates(context);
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _currentIndex = index;
    });
    _sidebarController.selectIndex(index);
  }

  List<SidebarXItem> _navigationItems() => [
        SidebarXItem(
          icon: Icons.home,
          label: 'Home',
          onTap: () => _selectPage(0),
        ),
        SidebarXItem(
          icon: Icons.wifi_find,
          label: 'Scan your network',
          onTap: () => _selectPage(1),
        ),
        SidebarXItem(
          icon: Icons.signal_cellular_alt,
          label: 'Service Provider Details',
          onTap: () => _selectPage(10),
        ),
        SidebarXItem(
          icon: Icons.trending_up,
          label: 'Check a website',
          onTap: () => _selectPage(2),
        ),
        SidebarXItem(
          icon: Icons.monitor_heart,
          label: 'Monitor server',
          onTap: () => _selectPage(3),
        ),
        SidebarXItem(
          icon: Icons.radar,
          label: 'Find security gaps',
          onTap: () => _selectPage(4),
        ),
        SidebarXItem(
          icon: Icons.search,
          label: 'Find website addresses',
          onTap: () => _selectPage(7),
        ),
        SidebarXItem(
          icon: Icons.find_replace,
          label: 'Find a device name',
          onTap: () => _selectPage(8),
        ),
        SidebarXItem(
          icon: Icons.account_tree,
          label: 'Subnet calculator',
          onTap: () => _selectPage(9),
        ),
        SidebarXItem(
          icon: Icons.hub,
          label: 'Find switch',
          onTap: () => _selectPage(5),
        ),
        SidebarXItem(
          icon: Icons.power_settings_new,
          label: 'Wake on LAN',
          onTap: () => _selectPage(6),
        ),
      ];

  Widget _buildSidebar(
    BuildContext context, {
    required bool showToggleButton,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SidebarX(
      controller: _sidebarController,
      showToggleButton: showToggleButton,
      theme: SidebarXTheme(
        width: 72,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        hoverColor: colors.surfaceContainerHighest,
        textStyle: TextStyle(color: colors.onSurfaceVariant),
        selectedTextStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 20),
        selectedIconTheme: IconThemeData(color: colors.primary, size: 20),
        hoverIconTheme: IconThemeData(color: colors.primary, size: 20),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        itemMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        selectedItemMargin:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        itemTextPadding: const EdgeInsets.only(left: 14),
        selectedItemTextPadding: const EdgeInsets.only(left: 14),
        selectedItemDecoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extendedTheme: SidebarXTheme(
        width: 272,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      headerBuilder: (context, isExtended) => SizedBox(
        height: 72,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showAppName = isExtended && constraints.maxWidth >= 200;
            final logoSize = constraints.maxWidth < 56 ? 24.0 : 36.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: showAppName ? 12 : 4),
              child: Align(
                alignment:
                    showAppName ? Alignment.centerLeft : Alignment.center,
                child: showAppName
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Vernet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
      separatorBuilder: (context, index) {
        if (index == 2 || index == 5 || index == 8) {
          return Divider(
            height: 16,
            indent: _sidebarController.extended ? 16 : 8,
            endIndent: _sidebarController.extended ? 16 : 8,
            color: colors.outlineVariant,
          );
        }
        return const SizedBox(height: 4);
      },
      footerDivider: Divider(height: 1, color: colors.outlineVariant),
      footerBuilder: (context, isExtended) {
        final settingsIndex = _navigationItems().length;
        final isSelected = _currentIndex == settingsIndex;
        final foreground =
            isSelected ? colors.primary : colors.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Material(
            key: const ValueKey('sidebar-settings'),
            color: isSelected ? colors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _selectPage(settingsIndex);
              },
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showLabel =
                          isExtended && constraints.maxWidth >= 200;
                      return Row(
                        mainAxisAlignment: showLabel
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(Icons.settings, size: 20, color: foreground),
                          if (showLabel) ...[
                            const SizedBox(width: 14),
                            Text(
                              'Settings',
                              style: TextStyle(
                                color: isSelected
                                    ? foreground
                                    : colors.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      items: _navigationItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth <= _largeLayoutBreakpoint;
        final page = _selectedPage;
        return Scaffold(
          key: _scaffoldKey,
          appBar: isCompact
              ? AppBar(
                  title: Text(_selectedPageTitle),
                  leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                )
              : null,
          drawer: isCompact
              ? Drawer(
                  child: SafeArea(
                    bottom: false,
                    child: _buildSidebar(context, showToggleButton: false),
                  ),
                )
              : null,
          body: isCompact
              ? page
              : SafeArea(
                  child: Row(
                    children: [
                      _buildSidebar(context, showToggleButton: true),
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(child: page),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String get _selectedPageTitle => switch (_currentIndex) {
        0 => 'Home',
        1 => 'Scan your network',
        2 => 'Check a website',
        3 => 'Monitor server',
        4 => 'Find security gaps',
        5 => 'Find switch',
        6 => 'Wake on LAN',
        7 => 'Find website addresses',
        8 => 'Find a device name',
        9 => 'Subnet calculator',
        10 => 'Service Provider Details',
        _ => 'Settings',
      };

  Widget get _selectedPage => switch (_currentIndex) {
        0 => const HomePage(),
        1 => HostScanPage(),
        2 => const PingPage(),
        3 => const ServerCheckerPage(),
        4 => const PortScanPage(),
        5 => const NeighborDiscoveryPage(),
        6 => const WakeOnLanPage(),
        7 => const DNSPage(),
        8 => const ReverseDNSPage(),
        9 => const SubnetCalculatorPage(),
        10 => const _InternetServicePage(),
        _ => const SettingsPage(),
      };
}

class _InternetServicePage extends StatefulWidget {
  const _InternetServicePage();

  @override
  State<_InternetServicePage> createState() => _InternetServicePageState();
}

class _InternetServicePageState extends State<_InternetServicePage> {
  final SpeedTestDart _tester = SpeedTestDart();
  final IspLookupService _ispLookupService = IspLookupService();
  late final Future<Settings?> _settingsFuture = _loadSettings();

  Future<Settings?> _loadSettings() async {
    if (!appSettings.inAppInternet) return null;
    final settings =
        await _tester.getSettings(headers: {"User-Agent": "Mozilla/4.0"});
    if (settings.client.isp.trim().isEmpty ||
        settings.client.isp.toLowerCase() == 'unknown') {
      final isp = await _ispLookupService.lookup(settings.client.ip);
      if (isp != null) settings.client.isp = isp;
    }
    return settings;
  }

  @override
  Widget build(BuildContext context) {
    if (!appSettings.inAppInternet) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Provider Details')),
        body: const Center(
          child: Text('Turn on internet access in Settings to continue.'),
        ),
      );
    }
    return FutureBuilder<Settings?>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Service Provider Details')),
            body: const Center(
              child: Text('Provider details are currently unavailable.'),
            ),
          );
        }
        final settings = snapshot.data;
        if (settings == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Service Provider Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return IspPage(tester: _tester, settings: settings);
      },
    );
  }
}
