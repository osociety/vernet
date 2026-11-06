import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Measurement strategy for macOS, Windows, and Linux.
///
/// Encodes the methodologies that validated against reference tools on
/// desktop: download is measured client-side (the original implementation,
/// 223 Mbps = exact M-Lab match; server TCPInfo overshot at 292-462 Mbps
/// because the sender counts in-flight data), upload uses the latest
/// server-side receiver sample (177 vs ~150 plan, the closest reading
/// observed). Desktop sockets drain fast enough that client-side byte
/// counting tracks the wire rate closely, so it is allowed as a fallback in
/// both directions when the server reports nothing usable.
class DesktopNdt7Strategy implements Ndt7Strategy {
  const DesktopNdt7Strategy();

  @override
  String get label => 'desktop';

  @override
  Ndt7ThroughputTracker createDownloadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ClientSamplesTracker(settings: settings);

  @override
  Ndt7ThroughputTracker createUploadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ServerCumulativeTracker(
        settings: settings,
        direction: Ndt7Direction.upload,
        useClientFallback: true,
      );
}
