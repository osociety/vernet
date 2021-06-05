import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'helper/app_settings.dart';
import 'helper/consent.dart';
import 'models/dark_theme_provider.dart';
import 'pages/home_page.dart';

late AppSettings appSettings;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool allowed = await Consent.isConsentPageShown();
  appSettings = AppSettings.instance..load();
  runApp(MyApp(allowed));
}

class MyApp extends StatefulWidget {
  final bool allowed;
  const MyApp(this.allowed, {Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DarkThemeProvider themeChangeProvider = new DarkThemeProvider();

  @override
  void initState() {
    super.initState();
    getCurrentAppTheme();
  }

  void getCurrentAppTheme() async {
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
            home: widget.allowed ? HomePage() : LocationConsentPage(),
          );
        },
      ),
    );
  }
}
