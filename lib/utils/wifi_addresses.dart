/// The gateway the dashboard shows and the address the host scan targets.
///
/// A saved custom subnet seeds "Search a different network", so it replaces
/// only the scan target. The gateway stays the one the platform reported, which
/// is what stops the seed address being shown as the router (#646).
({String gatewayIp, String? scanSubnet}) resolveWifiAddresses({
  required String? reportedGatewayIp,
  required String? wifiIp,
  required String customSubnet,
}) {
  final seed = customSubnet.trim();
  return (
    gatewayIp: (reportedGatewayIp ?? wifiIp) ?? '',
    scanSubnet: seed.isEmpty ? null : seed,
  );
}
