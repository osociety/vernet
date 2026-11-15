import 'package:vernet/l10n/app_localizations.dart';

/// Strength of the Wi-Fi link, as the app reports it to the user.
///
/// The first five cases map onto the dBm bands in `WifiRepository`; the last
/// three say why there is no band to report.
enum WifiSignalQuality {
  excellent,
  good,
  fair,
  weak,
  criticallyLow,
  noReading,
  disconnected,
  locationMissing,
}

extension WifiSignalQualityLabel on WifiSignalQuality {
  String label(AppLocalizations l10n) => switch (this) {
        WifiSignalQuality.excellent => l10n.signalExcellent,
        WifiSignalQuality.good => l10n.signalGood,
        WifiSignalQuality.fair => l10n.signalFair,
        WifiSignalQuality.weak => l10n.signalWeak,
        WifiSignalQuality.criticallyLow => l10n.signalCriticallyLow,
        WifiSignalQuality.noReading => l10n.signalNoReading,
        WifiSignalQuality.disconnected => l10n.signalDisconnected,
        WifiSignalQuality.locationMissing => l10n.signalLocationMissing,
      };
}

/// A cross-platform result container for hardware Wi-Fi network analytics
class WifiNetworkMetrics {
  const WifiNetworkMetrics({
    required this.rawRssi,
    required this.normalizedLevel,
    required this.quality,
  });

  factory WifiNetworkMetrics.disconnected() {
    return const WifiNetworkMetrics(
      rawRssi: null,
      normalizedLevel: 0,
      quality: WifiSignalQuality.disconnected,
    );
  }

  /// The reading was asked for and nothing answered it.
  ///
  /// This is not a disconnection: only the caller knows the link state, and
  /// saying "disconnected" here is what made a working Linux connection look
  /// broken. A 0 dBm would be a stronger signal than any real access point
  /// emits, so the field stays null instead of carrying a fake value.
  factory WifiNetworkMetrics.noReading() {
    return const WifiNetworkMetrics(
      rawRssi: null,
      normalizedLevel: 0,
      quality: WifiSignalQuality.noReading,
    );
  }

  final int? rawRssi; // The actual hardware dBm value (e.g. -55)
  final int normalizedLevel; // Normalized strength index mapping from 0 to 4
  final WifiSignalQuality quality;
}
