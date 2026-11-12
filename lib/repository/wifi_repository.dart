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
        final int calculatedDbm = dbmFromSignalPercent(percentage);
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
        return await _linuxSignalDbm();
      }
    } catch (desktopError) {
      debugPrint("Desktop CLI internal processing error: $desktopError");
    }
    return null;
  }

  /// Signal of the network Linux is associated with, in dBm, from the first
  /// source that knows.
  ///
  /// `/proc/net/wireless` is the old WEXT interface: mac80211 and iwd drivers,
  /// which is everything current, do not create it, so reading only that file
  /// reported no signal on a healthy connection.
  static Future<int?> _linuxSignalDbm() async {
    return await _iwSignalDbm() ??
        await _nmcliSignalDbm() ??
        await _wirelessFileSignalDbm();
  }

  static Future<int?> _iwSignalDbm() async {
    for (final String interface
        in parseIwInterfaces(await _run('iw', const ['dev']))) {
      final int? dbm =
          parseIwLinkOutput(await _run('iw', ['dev', interface, 'link']));
      if (dbm != null) return dbm;
    }
    return null;
  }

  static Future<int?> _nmcliSignalDbm() async {
    return parseNmcliWifiListOutput(await _run(
        'nmcli', const ['-t', '-f', 'IN-USE,SIGNAL', 'dev', 'wifi', 'list']));
  }

  static Future<int?> _wirelessFileSignalDbm() async {
    final File file = File('/proc/net/wireless');
    if (!await file.exists()) return null;
    return parseProcNetWireless(await file.readAsLines());
  }

  /// Wi-Fi interfaces named by `iw dev`, which lists one block per interface
  /// under its phy.
  @visibleForTesting
  static List<String> parseIwInterfaces(String output) {
    return RegExp(r'^\s*Interface\s+(\S+)', multiLine: true)
        .allMatches(output)
        .map((match) => match.group(1)!)
        .toList();
  }

  /// dBm from `iw dev <interface> link`, whose connected block prints
  /// `signal: -48 dBm` (older iw writes it without the colon).
  @visibleForTesting
  static int? parseIwLinkOutput(String output) {
    final RegExpMatch? match =
        RegExp(r'signal:?\s*(-?\d+)\s*dBm').firstMatch(output);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// dBm from `nmcli -t -f IN-USE,SIGNAL dev wifi list`, where the associated
  /// network is the one whose IN-USE flag is `*`. NetworkManager reports a
  /// 0-100 link quality rather than a signal level, so it is mapped the way
  /// the Windows reading is.
  @visibleForTesting
  static int? parseNmcliWifiListOutput(String output) {
    for (final String line in output.split('\n')) {
      final List<String> fields = line.split(':');
      if (fields.length < 2 || fields.first.trim() != '*') continue;
      final int? percent = int.tryParse(fields[1].trim());
      if (percent == null || percent <= 0) continue;
      return dbmFromSignalPercent(percent);
    }
    return null;
  }

  /// dBm from `/proc/net/wireless`, whose two header rows are followed by
  /// `wlp2s0: 0000   74.  -48.  -53` — link quality, then level, then noise.
  @visibleForTesting
  static int? parseProcNetWireless(List<String> lines) {
    if (lines.length <= 2) return null;
    for (final String line in lines.sublist(2)) {
      final List<String> tokens = line.trim().split(RegExp(r'\s+'));
      if (tokens.length < 4) continue;
      final int? dbm =
          int.tryParse(tokens[3].replaceAll(RegExp('[^0-9-]'), ''));
      if (dbm != null) return dbm;
    }
    return null;
  }

  /// Maps a 0-100 link quality percentage to the same estimated dBm window the
  /// Windows layer uses.
  @visibleForTesting
  static int dbmFromSignalPercent(int percent) =>
      ((-100) + (percent * 0.7)).round();

  static Future<String> _run(String executable, List<String> arguments) async {
    try {
      final ProcessResult result = await Process.run(executable, arguments);
      return result.stdout.toString();
    } catch (missingTool) {
      // Neither tool is guaranteed on a desktop: containers and minimal
      // installs simply have no Wi-Fi to report.
      debugPrint('$executable is unavailable: $missingTool');
      return '';
    }
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
    if (rssi >= -55) return "Excellent";
    if (rssi >= -67) return "Good";
    if (rssi >= -78) return "Fair";
    if (rssi >= -90) return "Weak";
    return "Critically Low";
  }
}
