class SubnetCalculation {
  const SubnetCalculation({
    required this.ipVersion,
    required this.cidr,
    required this.networkAddress,
    required this.subnetMask,
    required this.firstAddress,
    required this.lastAddress,
    required this.addressCount,
    this.broadcastAddress,
  });

  final String ipVersion;
  final String cidr;
  final String networkAddress;
  final String subnetMask;
  final String firstAddress;
  final String lastAddress;
  final String addressCount;
  final String? broadcastAddress;
}
