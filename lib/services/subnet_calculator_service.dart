import 'dart:io';
import 'dart:typed_data';

import 'package:vernet/models/subnet_calculation.dart';

class SubnetCalculatorService {
  const SubnetCalculatorService();

  SubnetCalculation calculate(String input) {
    final value = input.trim();
    final slash = value.lastIndexOf('/');
    if (slash <= 0 || slash == value.length - 1) {
      throw const FormatException(
        'Enter an IP address followed by a prefix, such as 192.168.1.10/24.',
      );
    }

    final addressText = value.substring(0, slash).trim();
    final prefixText = value.substring(slash + 1).trim();
    final prefix = int.tryParse(prefixText);
    if (prefix == null) {
      throw const FormatException('The prefix must be a number.');
    }

    final address = InternetAddress.tryParse(addressText);
    if (address == null) {
      throw const FormatException('Enter a valid IPv4 or IPv6 address.');
    }

    if (address.type == InternetAddressType.IPv4) {
      return _calculateIpv4(address.rawAddress, prefix);
    }
    if (address.type == InternetAddressType.IPv6) {
      return _calculateIpv6(address.rawAddress, prefix);
    }
    throw const FormatException('Enter a valid IPv4 or IPv6 address.');
  }

  SubnetCalculation _calculateIpv4(List<int> bytes, int prefix) {
    if (prefix < 0 || prefix > 32) {
      throw const FormatException('IPv4 prefixes must be between 0 and 32.');
    }
    final address = _toBigInt(bytes);
    final all = (BigInt.one << 32) - BigInt.one;
    final mask = prefix == 0 ? BigInt.zero : (all << (32 - prefix)) & all;
    final network = address & mask;
    final broadcast = network | (all ^ mask);
    final hostBits = 32 - prefix;
    final count = BigInt.one << hostBits;
    final first = prefix <= 30 ? network + BigInt.one : network;
    final last = prefix <= 30 ? broadcast - BigInt.one : broadcast;

    return SubnetCalculation(
      ipVersion: 'IPv4',
      cidr: '$prefix',
      networkAddress: _formatIpv4(network),
      subnetMask: _formatIpv4(mask),
      firstAddress: _formatIpv4(first),
      lastAddress: _formatIpv4(last),
      broadcastAddress: _formatIpv4(broadcast),
      addressCount: count.toString(),
    );
  }

  SubnetCalculation _calculateIpv6(List<int> bytes, int prefix) {
    if (prefix < 0 || prefix > 128) {
      throw const FormatException('IPv6 prefixes must be between 0 and 128.');
    }
    final address = _toBigInt(bytes);
    final all = (BigInt.one << 128) - BigInt.one;
    final mask = prefix == 0 ? BigInt.zero : (all << (128 - prefix)) & all;
    final network = address & mask;
    final finalAddress = network | (all ^ mask);
    final hostBits = 128 - prefix;

    return SubnetCalculation(
      ipVersion: 'IPv6',
      cidr: '$prefix',
      networkAddress: _formatIpv6(network),
      subnetMask: _formatIpv6(mask),
      firstAddress: _formatIpv6(network),
      lastAddress: _formatIpv6(finalAddress),
      addressCount: (BigInt.one << hostBits).toString(),
    );
  }

  BigInt _toBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  String _formatIpv4(BigInt value) => List<String>.generate(4, (index) {
        final shift = (3 - index) * 8;
        return ((value >> shift) & BigInt.from(255)).toString();
      }).join('.');

  String _formatIpv6(BigInt value) {
    final bytes = Uint8List.fromList(List<int>.generate(16, (index) {
      final shift = (15 - index) * 8;
      return ((value >> shift) & BigInt.from(255)).toInt();
    }));
    return InternetAddress.fromRawAddress(
      bytes,
      type: InternetAddressType.IPv6,
    ).address;
  }
}
