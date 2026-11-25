import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/dns/dns_page.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/pages/donate_page.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/neighbor_discovery_page/neighbor_discovery_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/onboarding/language_page.dart';
import 'package:vernet/pages/onboarding/walkthrough_page.dart';
import 'package:vernet/pages/onboarding/wifi_prompt_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/pages/subnet_calculator_page.dart';
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/store/store_features.dart';
import 'package:vernet/ui/adaptive/shell_chrome.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/utils/app_strings.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/globals.dart' as globals;

AppSettings appSettings = AppSettings.instance;
Future<void> main() async {
  // debugPrint writes to the system log in release builds too, so shipping
  // installs would leak scan internals to user devices. Reassigning the global
  // also silences debugPrint inside the vendored network_tools packages.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  configureDependencies(Env.prod);

  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  if (Platform.isAndroid) {
    SharedPreferencesAndroid.registerWith();
  }

  try {
    final appDocDirectory = await getApplicationDocumentsDirectory();
    await configureNetworkToolsFlutter(appDocDirectory.path);
  } catch (e, st) {
    debugPrint('Network tools init failed: $e\n$st');
  }

  final stage = await OnboardingService.instance.resolveStage();
  await appSettings.load();

  await NotificationService.initNotification();

  if (kStoreBuild) {
    await initializeStoreSdk();
  }

  runApp(MyApp(stage));
  FlutterNativeSplash.remove();
  unawaited(_warmUpDatabase());
}

Future<void> _warmUpDatabase() async {
  try {
    await getIt<DatabaseService<AppDatabase>>().open();
  } catch (error) {
    debugPrint('Database warm-up failed: $error');
  }
}

class MyApp extends StatefulWidget {
  const MyApp(this.onboardingStage, {super.key, this.testing = false});
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final OnboardingStage? onboardingStage;
  final bool testing;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  LocaleProvider localeProvider = LocaleProvider();
  StreamSubscription<String?>? _notificationTapSubscription;

  /// A notification that opens a report stays opened until the user leaves it,
  /// so the launch payload and the stream response for one tap cannot stack two
  /// copies of the same page.
  bool _openingScanReport = false;

  @override
  void initState() {
    super.initState();
    if (widget.testing) globals.testingActive = true;
    if (!globals.testingActive) {
      NotificationService.grantPermissions();
    }
    _notificationTapSubscription = NotificationService
        .selectNotificationStream.stream
        .listen(_handleNotificationTap);
    // Tapping while the app was stopped delivers the payload during
    // `initNotification`, before anything listens to the stream.
    final launchPayload = NotificationService.selectedNotificationPayload;
    if (launchPayload != null) {
      NotificationService.selectedNotificationPayload = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationTap(launchPayload),
      );
    }
    getCurrentAppTheme();
    getCurrentAppLocale();
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (NotificationService.isUntrustedDevicesPayload(payload)) {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) return;
      await Navigator.push<void>(
        navigator.context,
        MaterialPageRoute<void>(
          builder: (_) => const TrustedDevicesPage(),
        ),
      );
      return;
    }
    await _openScanFromNotification(payload);
  }

  Future<void> _openScanFromNotification(String? payload) async {
    if (!NotificationService.isScanPayload(payload)) {
      return;
    }
    final navigator = MyApp.navigatorKey.currentState;
    if (navigator == null || _openingScanReport) {
      return;
    }
    _openingScanReport = true;
    ScanData? scan;
    try {
      final repository = getIt<ScanRepository>();
      final scanId = NotificationService.scanIdFromPayload(payload);
      if (scanId != null) scan = await repository.get(scanId);
      if (scan == null) {
        // Notifications written before the payload carried an id, and scans
        // pruned from the history, both fall back to the newest report.
        final recent = await repository.getRecentScans(limit: 1);
        scan = recent.isEmpty ? null : recent.first;
      }
    } catch (error) {
      debugPrint('Could not load the scan report: $error');
    }

    try {
      // The scan page is not an option here: it starts a fresh search, while a
      // tapped notification promises the results that were already found.
      final report = scan;
      if (!navigator.mounted) return;
      await Navigator.push<void>(
        navigator.context,
        MaterialPageRoute<void>(
          builder: (context) => report == null
              ? const ScanHistoryPage()
              : ScanDetailPage(scan: report),
        ),
      );
    } finally {
      _openingScanReport = false;
    }
  }

  Future<void> getCurrentAppTheme() async {
    themeChangeProvider.themePref =
        await themeChangeProvider.darkThemePreference.getTheme();
  }

  Future<void> getCurrentAppLocale() async {
    localeProvider.locale = await localeProvider.localePreference.getLocale();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeChangeProvider),
        ChangeNotifierProvider(create: (_) => localeProvider),
      ],
      child: Consumer2<DarkThemeProvider, LocaleProvider>(
        builder: (BuildContext context, theme, locale, Widget? child) {
          return MaterialApp(
            navigatorKey: MyApp.navigatorKey,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                    builder: (context) => homePage,
                  );

                default:
                  assert(false, 'Page ${settings.name} not found');
                  return null;
              }
            },
            title: 'Vernet',
            theme: createSemanticTheme(theme.darkTheme),
            locale: locale.locale,
            // Flutter's fallback for a language Vernet does not ship is
            // supportedLocales.first, and gen-l10n orders that list by ARB
            // filename, so a Russian or Polish device rendered German while the
            // service layer read English. This callback runs before that
            // fallback, so both layers agree on English.
            localeListResolutionCallback: (systemLocales, supportedLocales) =>
                resolveSystemLocale(systemLocales ?? const []),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: homePage,
          );
        },
      ),
    );
  }

  Widget get homePage {
    final stage = widget.onboardingStage;
    if (stage != null) {
      switch (stage) {
        case OnboardingStage.language:
          return const LanguagePage();
        case OnboardingStage.walkthrough:
          return const WalkthroughPage();
        case OnboardingStage.consent:
          return const LocationConsentPage();
      }
    }
    return const TabBarPage();
  }
}

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});

  /// The width at or below which the shell shows a drawer and its own bar
  /// instead of the rail and the page heading.
  ///
  /// A test that asserts which heading a destination carries needs the number
  /// the shell actually branches on.
  static const double largeLayoutBreakpoint = 600;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<TabBarPage> {
  /// The rail and the page share a `Row`, so every frame of the extension
  /// tween re-lays out the page. A shorter tween means fewer of those frames.
  static const Duration _toggleAnimation = Duration(milliseconds: 200);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SidebarXController _sidebarController;

  /// The destination list, kept between builds so navigating does not rebuild
  /// eleven items and eleven `onTap` closures. [AppLocalizations] hands back one
  /// instance per locale, so that identity is the locale-changed signal.
  AppLocalizations? _navStrings;
  List<SidebarXItem>? _navItems;

  /// The rail as one cached widget instance, valid while the [ColorScheme], the
  /// layout mode and the destination list are. Dragging a desktop window re-runs
  /// the `LayoutBuilder` in `build` on every frame, and handing `SidebarX` an
  /// identical config then makes Flutter skip it instead of re-merging two
  /// themes and re-listening eleven cells a frame.
  Widget? _rail;
  ColorScheme? _railColors;
  List<SidebarXItem>? _railNavItems;
  bool? _railIsCompact;

  @override
  void initState() {
    super.initState();
    _sidebarController = SidebarXController(selectedIndex: 0, extended: true);
    if (kUpdateChecksEnabled) {
      checkForUpdates(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingPrompts();
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  Future<void> _showOnboardingPrompts() async {
    if (!mounted) return;
    await _maybeShowWifiPrompt();
  }

  Future<void> _maybeShowWifiPrompt() async {
    if (globals.testingActive) return;
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) return;
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      final hasWifi = wifiIp != null &&
          wifiIp.isNotEmpty &&
          wifiIp != 'x.x.x.x' &&
          wifiIp != '0.0.0.0';
      if (!hasWifi && mounted) {
        await WifiPromptSheet.show(context);
      }
    } catch (_) {
      // WiFi detection failure is non-fatal; skip the prompt.
    }
  }

  /// Opens the destination at row [index].
  ///
  /// [index] is the row's position in [_navigationItems], which is also what
  /// `SidebarX` writes to the controller itself after invoking an item's
  /// `onTap` (`_onItemSelected` calls `selectIndex(listIndex)` whenever the item
  /// is `selectable`). So a row whose `onTap` names a different number is
  /// overwritten and opens the page of the row it sits above, and the highlight
  /// and the page agree on the wrong one. The Settings footer is outside that
  /// mechanism and keeps its own index of `items.length`.
  void _selectPage(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    // The controller holds the only copy of the selection, and notifying it is
    // what rebuilds the rail and the content scope below. Rebuilding this state
    // on top of that would rebuild the rail a second time, so it does not.
    if (_sidebarController.selectedIndex != index) {
      _sidebarController.selectIndex(index);
    }
    // Opening Settings is the deepest commit a session reaches, so it is where
    // Play is asked for a review. Only the store build has the SDK.
    if (kStoreBuild && index == _navigationItems(context).length) {
      unawaited(requestStoreReview());
    }
  }

  List<SidebarXItem> _navigationItems(BuildContext context) {
    final cached = _navItems;
    final l10n = context.l10n;
    if (cached != null && identical(l10n, _navStrings)) return cached;

    final items = _buildNavigationItems(l10n);
    _navStrings = l10n;
    _navItems = items;
    return items;
  }

  List<SidebarXItem> _buildNavigationItems(AppLocalizations l10n) {
    return [
      SidebarXItem(
        icon: Icons.home,
        label: l10n.navHome,
        onTap: () => _selectPage(0),
      ),
      SidebarXItem(
        icon: Icons.wifi_find,
        label: l10n.navScanNetwork,
        onTap: () => _selectPage(1),
      ),
      SidebarXItem(
        icon: Icons.trending_up,
        label: l10n.navCheckWebsite,
        onTap: () => _selectPage(2),
      ),
      SidebarXItem(
        icon: Icons.monitor_heart,
        label: l10n.navMonitorServer,
        onTap: () => _selectPage(3),
      ),
      SidebarXItem(
        icon: Icons.radar,
        label: l10n.navFindSecurityGaps,
        onTap: () => _selectPage(4),
      ),
      SidebarXItem(
        icon: Icons.search,
        label: l10n.navFindWebsiteAddresses,
        onTap: () => _selectPage(5),
      ),
      SidebarXItem(
        icon: Icons.find_replace,
        label: l10n.navFindDeviceName,
        onTap: () => _selectPage(6),
      ),
      SidebarXItem(
        icon: Icons.account_tree,
        label: l10n.navSubnetCalculator,
        onTap: () => _selectPage(7),
      ),
      SidebarXItem(
        icon: Icons.hub,
        label: l10n.navFindSwitch,
        onTap: () => _selectPage(8),
      ),
      SidebarXItem(
        icon: Icons.power_settings_new,
        label: l10n.navWakeOnLan,
        onTap: () => _selectPage(9),
      ),
      SidebarXItem(
        icon: Icons.volunteer_activism,
        label: l10n.navSupport,
        onTap: () => _selectPage(10),
      ),
    ];
  }

  /// The mark at the top of the rail, decoded at the size it is painted.
  ///
  /// `assets/app_icon.png` is 512px square while the header asks for 24 or 36,
  /// so without `cacheWidth` the image cache holds a full 1 MB RGBA buffer for a
  /// logo the size of a stamp.
  Widget _logo(BuildContext context, double size) {
    return ClipOval(
      child: Image.asset(
        'assets/app_icon.png',
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, bool isExtended) {
    return SizedBox(
      height: 72,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAppName = isExtended && constraints.maxWidth >= 200;
          final logoSize = constraints.maxWidth < 56 ? 24.0 : 36.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: showAppName ? 12 : 4),
            child: Align(
              alignment: showAppName ? Alignment.centerLeft : Alignment.center,
              child: showAppName
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _logo(context, logoSize),
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
                  : _logo(context, logoSize),
            ),
          );
        },
      ),
    );
  }

  /// The rail, or the exact widget instance handed out last time if nothing it
  /// depends on has changed.
  Widget _railFor(BuildContext context, {required bool isCompact}) {
    final colors = Theme.of(context).colorScheme;
    final navItems = _navigationItems(context);
    final cached = _rail;
    if (cached != null &&
        identical(colors, _railColors) &&
        identical(navItems, _railNavItems) &&
        _railIsCompact == isCompact) {
      return cached;
    }

    final rail = RepaintBoundary(
      child: _buildSidebar(
        context,
        items: navItems,
        showToggleButton: !isCompact,
      ),
    );
    _rail = rail;
    _railColors = colors;
    _railNavItems = navItems;
    _railIsCompact = isCompact;
    return rail;
  }

  Widget _buildSidebar(
    BuildContext context, {
    required List<SidebarXItem> items,
    required bool showToggleButton,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SidebarX(
      controller: _sidebarController,
      showToggleButton: showToggleButton,
      animationDuration: _toggleAnimation,
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
      headerBuilder: _buildSidebarHeader,
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
        final settingsIndex = items.length;
        final isSelected = _sidebarController.selectedIndex == settingsIndex;
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
                              context.l10n.navSettings,
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
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth <= TabBarPage.largeLayoutBreakpoint;
        final rail = _railFor(context, isCompact: isCompact);
        return Scaffold(
          key: _scaffoldKey,
          appBar: isCompact
              ? AppBar(
                  title: ListenableBuilder(
                    listenable: _sidebarController,
                    builder: (context, _) => Text(_selectedPageTitle(context)),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                )
              : null,
          drawer: isCompact ? Drawer(child: SafeArea(child: rail)) : null,
          body: isCompact
              ? SafeArea(child: _content(shellHasAppBar: true))
              : SafeArea(
                  child: Row(
                    children: [
                      rail,
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(child: _content(shellHasAppBar: false)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// The destination the controller points at, behind its own listen scope.
  ///
  /// Selecting a page and toggling the rail both notify the controller, and
  /// nothing else in the shell has to redraw for them. The boundary then keeps
  /// the page out of the repaints the widening rail causes on the frames where
  /// the row re-lays it out.
  ///
  /// [shellHasAppBar] is what the pages read through [ShellChrome] to decide
  /// whether to paint their own heading.
  Widget _content({required bool shellHasAppBar}) {
    return RepaintBoundary(
      child: ShellChrome(
        hasAppBar: shellHasAppBar,
        child: ListenableBuilder(
          listenable: _sidebarController,
          builder: (context, _) => _selectedPage,
        ),
      ),
    );
  }

  /// Compact app bar title. The sidebar labels the same destinations, except
  /// index 0, where the rail says `navHome` and the bar names the dashboard.
  String _selectedPageTitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (_sidebarController.selectedIndex) {
      0 => l10n.navYourNetwork,
      1 => l10n.navScanNetwork,
      2 => l10n.navCheckWebsite,
      3 => l10n.navMonitorServer,
      4 => l10n.navFindSecurityGaps,
      5 => l10n.navFindWebsiteAddresses,
      6 => l10n.navFindDeviceName,
      7 => l10n.navSubnetCalculator,
      8 => l10n.navFindSwitch,
      9 => l10n.navWakeOnLan,
      10 => l10n.navSupport,
      _ => l10n.navSettings,
    };
  }

  Widget get _selectedPage => switch (_sidebarController.selectedIndex) {
        0 => const HomePage(),
        1 => HostScanPage(),
        2 => const PingPage(),
        3 => const ServerCheckerPage(),
        4 => const PortScanPage(),
        5 => const DNSPage(),
        6 => const ReverseDNSPage(),
        7 => const SubnetCalculatorPage(),
        8 => const NeighborDiscoveryPage(),
        9 => const WakeOnLanPage(),
        10 => const DonatePage(),
        _ => const SettingsPage(),
      };
}
