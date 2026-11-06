import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Measurement strategy for Android and iOS.
///
/// Upload never trusts client-side byte counting: mobile stacks buffer
/// aggressively, so bytes-pushed-to-socket measures buffer fill, not the
/// wire — the server-side receiver counters are the only reliable upload
/// signal. Download falls back to client-side byte accounting because
/// received bytes are kernel-delivered and therefore wire-accurate.
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
