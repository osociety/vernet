import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:wifi_plus/wifi_plus.dart' as windows;
// Safe conditional platform imports to prevent compile-time crashes
import 'package:wifi_signal_strength_indicator/wifi_signal_strength_indicator.dart'
    as mobile;

class WifiRepository {
  /// Verifies OS permissions and fetches structural hardware network telemetry
  static Future<WifiNetworkMetrics> fetchWifiMetrics() async {
    if (kIsWeb) return WifiNetworkMetrics.disconnected();

    try {
      // 1. Mobile platforms (Android & iOS Layer)
      if (Platform.isAndroid || Platform.isIOS) {
        // Enforce structural hardware security checks required by mobile operating systems
        if (await Permission.location.request().isGranted) {
          final int? dbm = await mobile.WifiSignalStrength.getSignalStrength();
          final int? nativeLevel =
              await mobile.WifiSignalStrength.getSignalLevel();

          if (dbm == null) return WifiNetworkMetrics.disconnected();

          return WifiNetworkMetrics(
            rawRssi: dbm,
            normalizedLevel: nativeLevel ?? convertRssiToLevel(dbm),
            statusMessage: getDiagnosticString(dbm),
          );
        } else {
          return const WifiNetworkMetrics(
            rawRssi: null,
            normalizedLevel: 0,
            statusMessage: "Missing Required Location Permissions",
          );
        }
      }

      // 2. Windows Desktop Layer
      if (Platform.isWindows) {
        final details = await windows.WifiManager.currentConnection();
        final int percentage = details?.signalStrength ?? 0;

        if (percentage <= 0) return WifiNetworkMetrics.disconnected();

        // Inverse equation maps 0-100% telemetry to an estimated dBm window (-100 to -30 dBm)
        final int calculatedDbm = ((-100) + (percentage * 0.7)).round();
        return WifiNetworkMetrics(
          rawRssi: calculatedDbm,
          normalizedLevel: convertRssiToLevel(calculatedDbm),
          statusMessage: getDiagnosticString(calculatedDbm),
        );
      }

      // 3. macOS and Linux Core CLI Engine Fallbacks
      if (Platform.isMacOS || Platform.isLinux) {
        final int? desktopDbm = await _getDesktopFallbackRssi();
        if (desktopDbm == null) return WifiNetworkMetrics.disconnected();

        return WifiNetworkMetrics(
          rawRssi: desktopDbm,
          normalizedLevel: convertRssiToLevel(desktopDbm),
          statusMessage: getDiagnosticString(desktopDbm),
        );
      }
    } catch (error) {
      debugPrint("Cross-platform unified Wi-Fi metrics failure: $error");
    }

    return WifiNetworkMetrics.disconnected();
  }

  /// System execution methods targeting advanced desktop operating architectures
  static Future<int?> _getDesktopFallbackRssi() async {
    try {
      // macOS execution via System Profiler (Sonoma, Sequoia, and later compatible)
      if (Platform.isMacOS) {
        final ProcessResult result =
            await Process.run('system_profiler', ['SPAirPortDataType']);
        final String output = result.stdout.toString();

        // Target substring: "Signal / Noise: -54 dBm / -90 dBm"
        final RegExpMatch? match =
            RegExp(r'Signal\s*/\s*Noise:\s*(-?\d+)\s*dBm').firstMatch(output);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }

      // Linux internal device parsing path
      else if (Platform.isLinux) {
        final File file = File('/proc/net/wireless');
        if (await file.exists()) {
          final List<String> lines = await file.readAsLines();
          if (lines.length > 2) {
            final String operationalLine = lines[2].trim();
            final List<String> tokens = operationalLine.split(RegExp(r'\s+'));

            // Standard parsing index for absolute signal tracking metrics
            if (tokens.length > 3) {
              final double? rawValue =
                  double.tryParse(tokens[3].replaceAll('.', ''));
              if (rawValue != null) return rawValue.toInt();
            }
          }
        }
      }
    } catch (desktopError) {
      debugPrint("Desktop CLI internal processing error: $desktopError");
    }
    return null;
  }

  /// Utility scales converting hardware dBm ratings to explicit levels (0 to 4)
  @visibleForTesting
  static int convertRssiToLevel(int rssi) {
    if (rssi >= -55) return 4; // Perfect / High-density payload ready
    if (rssi >= -67) return 3; // Good / Multi-device streaming stable
    if (rssi >= -78) return 2; // Fair / Basic operations intact
    if (rssi >= -90) return 1; // Unstable / Edge of drop out
    return 0; // Completely dropped out
  }

  /// Evaluates specific networking thresholds for user diagnosis
  @visibleForTesting
  static String getDiagnosticString(int rssi) {
    if (rssi >= -55) return "Excellent Connection";
    if (rssi >= -67) return "Good, Stable Signal";
    if (rssi >= -78) return "Fair Connection";
    if (rssi >= -90) return "Weak Connection";
    return "Critically Low / Drop Out Risk";
  }
}
