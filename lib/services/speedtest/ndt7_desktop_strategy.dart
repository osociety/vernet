import 'package:vernet/services/speedtest/ndt7_measurement_strategy.dart';
import 'package:vernet/services/speedtest/ndt7_platform_settings.dart';

/// Measurement strategy for macOS, Windows, and Linux.
///
/// Desktop sockets drain fast enough that client-side byte counting tracks
/// the wire rate closely, so it is allowed as a last-resort fallback in both
/// directions. AppInfo goodput is preferred when the server provides it
/// because it excludes TCP/IP overhead.
class DesktopNdt7Strategy implements Ndt7Strategy {
  const DesktopNdt7Strategy();

  @override
  String get label => 'desktop';

  @override
  Ndt7ThroughputTracker createDownloadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ServerDeltaTracker(
        settings: settings,
        direction: Ndt7Direction.download,
        useClientFallback: true,
        preferAppInfo: true,
      );

  @override
  Ndt7ThroughputTracker createUploadTracker(
    Ndt7PlatformSettings settings,
  ) =>
      ServerDeltaTracker(
        settings: settings,
        direction: Ndt7Direction.upload,
        useClientFallback: true,
        preferAppInfo: true,
      );
}
