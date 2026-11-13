/// A cross-platform result container for hardware Wi-Fi network analytics
class WifiNetworkMetrics {
  // Human-readable diagnostics summary

  const WifiNetworkMetrics({
    required this.rawRssi,
    required this.normalizedLevel,
    required this.statusMessage,
  });
  factory WifiNetworkMetrics.disconnected() {
    return const WifiNetworkMetrics(
      rawRssi: null,
      normalizedLevel: 0,
      statusMessage: "Disconnected / Unknown State",
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
      statusMessage: "Signal unavailable",
    );
  }
  final int? rawRssi; // The actual hardware dBm value (e.g. -55)
  final int normalizedLevel; // Normalized strength index mapping from 0 to 4
  final String statusMessage;
}
