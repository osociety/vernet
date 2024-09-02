class StringValue {
  static const String firstSubnet = 'First Subnet';
  static const String firstSubnetDesc =
      'Scanning for hosts on the network will start from this value';

  static const String lastSubnet = 'Last Subnet';
  static const String lastSubnetDesc =
      'Scanning for hosts on the network will end on this value';

  static const String socketTimeout = 'Socket Timeout';
  static const String socketTimeoutdesc =
      'Connects for this much time to a port';

  static const String pingCount = 'Ping Count';
  static const String pingCountDesc =
      'Number of times ping request should be sent';

  static const String customSubnet = 'Custom Subnet';
  static const String customSubnetDesc =
      'Scan a custom subnet instead of local one.';
  static const String customSubnetHint = 'e.g., 10.102.200.1';
  static const String hostScanPageTitle = 'Scan for devices';
}
