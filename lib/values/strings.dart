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
  static const String loadingDevicesMessage =
      'Looking for devices connected to your local network';
  static const String dnsLookupEmptyPlaceholder =
      'No results yet.\nThe addresses for this website will appear here.';
  static const String reverseDnsLookupEmptyPlaceholder =
      'No name found yet.\nThe device name will appear here.';

  static const String speedTestServer =
      'Speed results provided by speedtest.net';

  static const String ispPageTitle = 'Internet provider';
}
