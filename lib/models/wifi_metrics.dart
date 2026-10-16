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
      rawRssi: 0,
      normalizedLevel: 0,
      statusMessage: "Disconnected / Unknown State",
    );
  }
  final int? rawRssi; // The actual hardware dBm value (e.g. -55)
  final int normalizedLevel; // Normalized strength index mapping from 0 to 4
  final String statusMessage;
}
