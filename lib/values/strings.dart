class StringValue {
  static const String firstSubnet = 'Start of device search';
  static const String firstSubnetDesc =
      'Choose the first number to check when looking for devices nearby';

  static const String lastSubnet = 'End of device search';
  static const String lastSubnetDesc =
      'Choose the last number to check when looking for devices nearby';

  static const String socketTimeout = 'Wait time for a check';
  static const String socketTimeoutdesc =
      'How long to wait for a device or service to respond';

  static const String pingCount = 'Number of connection checks';
  static const String pingCountDesc =
      'How many times to check whether a website or device responds';

  static const String customSubnet = 'Search a different network';
  static const String customSubnetDesc =
      'Use this only if you want to look for devices on another local network';
  static const String customSubnetHint = 'e.g., 10.0.0.1';
  static const String hostScanPageTitle = 'Find devices';
  static const String previousScansTitle = 'Previous scans';
  static const String scanReportTitle = 'Scan report';
  static const String scanHistoryEmptyPlaceholder =
      'No previous scans yet.\nRun a scan to see its report here.';
  static const String scanHistoryEmptyTitle = 'No scans yet';
  static const String scanHistoryRefresh = 'Refresh';
  static const String scanHistoryLoadError =
      'We could not load previous scans.';
  static const String scanHistoryOverviewTitle = 'Scan activity';
  static const String scanHistoryScansLabel = 'Scans';
  static const String scanHistoryDevicesFoundLabel = 'Devices found';
  static const String scanHistoryLatestScanLabel = 'Latest scan';
  static const String scanHistoryDevicesPerScanLabel =
      'Recent devices per scan';
  static const String scanHistoryListTitle = 'Scan history';
  static const String scanHistoryNetworkColumn = 'Network';
  static const String scanHistoryStartedColumn = 'Started';
  static const String scanHistoryDurationColumn = 'Duration';
  static const String scanHistoryDevicesColumn = 'Devices';
  static const String scanHistoryStatusColumn = 'Status';
  static const String scanReportCompleted = 'Completed';
  static const String scanReportInProgress = 'In progress';
  static const String scanReportDiscoveredDevices = 'Discovered devices';
  static const String scanReportNoDevices = 'No devices in this scan.';
  static const String scanReportLoadError = 'We could not load this report.';
  static const String scanReportScanWindow = 'Scan window';
  static const String scanReportStarted = 'Started';
  static const String scanReportEnded = 'Ended';
  static const String scanReportStillRunning = 'Still running';
  static const String scanReportDuration = 'Duration';
  static const String scanReportDeviceColumn = 'Device';
  static const String scanReportIpColumn = 'IP address';
  static const String scanReportMacColumn = 'MAC address';
  static const String scanReportDeviceLabel = 'Device';
  static const String scanReportDevicesLabel = 'Devices';
  static const String unknownDevice = 'Unknown device';
  static const String loadingDevicesMessage =
      'Looking for devices connected to your local network';
  static const String dnsLookupEmptyPlaceholder =
      'No results yet.\nThe addresses for this website will appear here.';
  static const String reverseDnsLookupEmptyPlaceholder =
      'No name found yet.\nThe device name will appear here.';

  static const String speedTestServer = 'Information provided by speedtest.net';

  static const String ispPageTitle = 'Service Provider Details';

  static const String neighborDiscoveryPageTitle = 'Switch neighbors';
  static const String neighborDiscoveryEmptyPlaceholder =
      'No neighbors yet.\nQuery a switch or paste CDP/LLDP CLI output to see ports and platforms.';

  static const String wakeOnLanPageTitle = 'Wake a device';
  static const String wakeOnLanEmptyPlaceholder =
      'No saved devices yet.\nEnter a MAC address and send a wake packet, or save a computer you use often.';
  static const String deviceDetailPageTitle = 'Device details';
  static const String signalStrength = 'Signal Strength';
  static const String signalStrengthUnit = 'dBm';
}
