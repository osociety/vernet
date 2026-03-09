import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

/// Shared test helpers for common mocking and setup.

/// Sets up SharedPreferences with initial values.
/// Call this in setUp() before tests that use SharedPreferences.
Future<void> setupSharedPreferences({
  Map<String, Object>? initialValues,
}) async {
  SharedPreferences.setMockInitialValues(initialValues ?? {});
}

/// Sets up PackageInfo mock with default values.
/// Call this in setUp() before tests that use PackageInfo.
void setupPackageInfoMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    },
  );
}

/// Sets up PackageInfo mock with custom values.
void setupPackageInfoMockCustom({
  String appName = 'vernet',
  String packageName = 'org.fsociety.vernet',
  String version = '1.0.0',
  String buildNumber = '1',
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': appName,
          'packageName': packageName,
          'version': version,
          'buildNumber': buildNumber,
        };
      }
      return null;
    },
  );
}

/// Wraps a widget with DarkThemeProvider.
Widget wrapWithDarkThemeProvider({
  required Widget child,
  bool initialDarkTheme = false,
}) {
  return ChangeNotifierProvider(
    create: (_) {
      final provider = DarkThemeProvider();
      provider.themePref = initialDarkTheme
          ? ThemePreference.dark
          : ThemePreference.light;
      return provider;
    },
    child: child,
  );
}

/// Common test data builders.
class TestDataBuilder {
  static Map<String, dynamic> createSharedPreferences({
    bool darkTheme = false,
    bool consentShown = false,
    String? subnet,
  }) {
    return {
      'dark_theme': darkTheme,
      'consent_page_shown': consentShown,
      if (subnet != null) 'subnet': subnet,
    };
  }
}
