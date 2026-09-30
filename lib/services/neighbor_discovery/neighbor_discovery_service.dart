import 'dart:async';
import 'dart:io';

import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/services/neighbor_discovery/cdp_parser.dart';
import 'package:vernet/services/neighbor_discovery/cli_neighbor_parser.dart';
import 'package:vernet/services/neighbor_discovery/lldp_parser.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_mib_mapper.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

class NeighborDiscoveryException implements Exception {
  const NeighborDiscoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Discovers CDP/LLDP neighbors by querying a switch over SNMP, or by parsing
/// frames and CLI output the user already has.
class NeighborDiscoveryService {
  NeighborDiscoveryService({SnmpClient? client})
      : _client = client ?? SnmpV2cClient();

  final SnmpClient _client;

  Future<NeighborDiscoveryResult> discover({
    required String switchIp,
    required String community,
    bool queryCdp = true,
    bool queryLldp = true,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (switchIp.trim().isEmpty) {
      throw const NeighborDiscoveryException('Enter a switch address');
    }
    if (!queryCdp && !queryLldp) {
      throw const NeighborDiscoveryException('Choose CDP, LLDP, or both');
    }

    final warnings = <String>[];
    SwitchIdentity identity;
    try {
      identity = await _loadIdentity(switchIp.trim(), community, timeout);
    } on TimeoutException {
      throw NeighborDiscoveryException(
        'No SNMP reply from ${switchIp.trim()}. Check the address, community, and that SNMP is allowed.',
      );
    } on SocketException {
      throw NeighborDiscoveryException(
        'Could not reach ${switchIp.trim()} over SNMP.',
      );
    } catch (e) {
      if (e is NeighborDiscoveryException) {
        rethrow;
      }
      throw NeighborDiscoveryException(
        'Could not reach ${switchIp.trim()} over SNMP.',
      );
    }

    Map<String, SnmpValue> ifNames = {};
    Map<String, SnmpValue> ifSpeeds = {};
    try {
      ifNames = await _client.walk(
        switchIp,
        community,
        NeighborMibs.ifName,
        timeout: timeout,
      );
      ifSpeeds = await _client.walk(
        switchIp,
        community,
        NeighborMibs.ifHighSpeed,
        timeout: timeout,
      );
    } catch (_) {
      warnings.add('Interface names or speeds were not available.');
    }

    final neighbors = <NeighborInfo>[];
    if (queryCdp) {
      try {
        final cache = await _client.walk(
          switchIp,
          community,
          NeighborMibs.cdpCache,
          timeout: timeout,
        );
        neighbors.addAll(
          NeighborMibMapper.mapCdp(
            cache: cache,
            ifNames: ifNames,
            ifSpeeds: ifSpeeds,
          ),
        );
      } on TimeoutException {
        warnings.add('CDP table did not respond (common on non-Cisco gear).');
      } catch (_) {
        warnings.add('CDP neighbors could not be read.');
      }
    }

    if (queryLldp) {
      try {
        final rem = await _client.walk(
          switchIp,
          community,
          NeighborMibs.lldpRem,
          timeout: timeout,
        );
        Map<String, SnmpValue> manAddr = {};
        Map<String, SnmpValue> locId = {};
        Map<String, SnmpValue> locDesc = {};
        Map<String, SnmpValue> vlans = {};
        try {
          manAddr = await _client.walk(
            switchIp,
            community,
            NeighborMibs.lldpRemManAddr,
            timeout: timeout,
          );
          locId = await _client.walk(
            switchIp,
            community,
            NeighborMibs.lldpLocPortId,
            timeout: timeout,
          );
          locDesc = await _client.walk(
            switchIp,
            community,
            NeighborMibs.lldpLocPortDesc,
            timeout: timeout,
          );
          vlans = await _client.walk(
            switchIp,
            community,
            NeighborMibs.lldpXdot1RemVlan,
            timeout: timeout,
          );
        } catch (_) {
          warnings.add('Some LLDP details (VLAN or management IP) were missing.');
        }
        neighbors.addAll(
          NeighborMibMapper.mapLldp(
            rem: rem,
            manAddr: manAddr,
            locPortId: locId,
            locPortDesc: locDesc,
            vlans: vlans,
            ifSpeeds: ifSpeeds,
          ),
        );
      } on TimeoutException {
        warnings.add('LLDP table did not respond.');
      } catch (_) {
        warnings.add('LLDP neighbors could not be read.');
      }
    }

    return NeighborDiscoveryResult(
      switchInfo: identity,
      neighbors: neighbors,
      warnings: warnings,
    );
  }

  Future<SwitchIdentity> _loadIdentity(
    String host,
    String community,
    Duration timeout,
  ) async {
    try {
      final name = await _client.get(
        host,
        community,
        NeighborMibs.sysName,
        timeout: timeout,
      );
      final descr = await _client.get(
        host,
        community,
        NeighborMibs.sysDescr,
        timeout: timeout,
      );
      return SwitchIdentity(
        ip: host,
        sysName: name?.asString,
        sysDescr: descr?.asString,
      );
    } on TimeoutException {
      rethrow;
    } on SocketException {
      rethrow;
    }
  }

  List<NeighborInfo> parseCli(String text) => CliNeighborParser.parse(text);

  NeighborInfo? parseFrame(List<int> bytes) {
    return CdpParser.parse(bytes) ?? LldpParser.parse(bytes);
  }
}
