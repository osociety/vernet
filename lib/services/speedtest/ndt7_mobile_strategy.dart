import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Measurement strategy for Android and iOS.
///
/// Download uses client-side byte counting with median-of-samples (same as
/// desktop): at 150+ Mbps, server TCPInfo deltas undershoot the wire rate
/// (86 Mbps measured vs Fing's 152 Mbps on a Redmi Note 7 Pro) because
/// Android's kernel counters don't update frequently enough to capture
/// bursts. Client-side received bytes are kernel-delivered and wire-accurate.
///
/// Upload stays on server TCPInfo deltas: mobile stacks buffer aggressively,
/// so client-side bytes-pushed-to-socket measures buffer fill, not the wire
/// (239.8 Mbps reported vs 26.4 actual at lower speeds).
class MobileNdt7Strategy implements Ndt7Strategy {
  const MobileNdt7Strategy();

  @override
  String get label => 'mobile';

  @override
  Ndt7ThroughputTracker createDownloadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ClientDeltaTracker(settings: settings);

  @override
  Ndt7ThroughputTracker createUploadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ServerDeltaTracker(
        settings: settings,
        direction: Ndt7Direction.upload,
        useClientFallback: false,
      );
}
