import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Measurement strategy for Android and iOS.
///
/// Encodes the methodologies that validated against reference tools on
/// mobile: both directions derive throughput from server TCPInfo deltas
/// (windowed deltas tracked the wire rate on a hotspot, 27 vs Fing's 26.4
/// Mbps, while client-side and cumulative server measures undershot).
/// Upload never trusts client-side byte counting: mobile stacks buffer
/// aggressively, so bytes-pushed-to-socket measures buffer fill, not the
/// wire (239.8 Mbps reported vs 26.4 actual). Download falls back to
/// client-side byte accounting because received bytes are kernel-delivered
/// and therefore wire-accurate.
class MobileNdt7Strategy implements Ndt7Strategy {
  const MobileNdt7Strategy();

  @override
  String get label => 'mobile';

  @override
  Ndt7ThroughputTracker createDownloadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ServerDeltaTracker(
        settings: settings,
        direction: Ndt7Direction.download,
        useClientFallback: true,
      );

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
