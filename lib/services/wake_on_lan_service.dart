import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/wake_on_lan_target.dart';
import 'package:wake_on_lan/wake_on_lan.dart';

class WakeOnLanException implements Exception {
  const WakeOnLanException(this.message);
  final String message;

  @override
  String toString() => message;
}

typedef WakeOnLanSender = Future<void> Function({
  required String macAddress,
  required String ipv4Address,
  int port,
  String? password,
  int repeat,
  Duration repeatDelay,
});

/// Sends Wake-on-LAN magic packets and stores named targets.
class WakeOnLanService {
  WakeOnLanService({
    WakeOnLanSender? sender,
    Future<SharedPreferences> Function()? prefs,
  })  : _sender = sender ?? sendWakeOnLanPacket,
        _prefs = prefs ?? SharedPreferences.getInstance;

  static const String savedTargetsKey = 'WakeOnLanService-SAVED-TARGETS';
  static const String defaultBroadcast = '255.255.255.255';
  static const int defaultPort = 9;
  static const int defaultRepeat = 3;

  final WakeOnLanSender _sender;
  final Future<SharedPreferences> Function() _prefs;

  Future<WakeOnLanResult> wake({
    required String macAddress,
    String ipv4Address = defaultBroadcast,
    int port = defaultPort,
    String? password,
    int repeat = defaultRepeat,
    Duration repeatDelay = const Duration(milliseconds: 200),
  }) async {
    final mac = normalizeMac(macAddress);
    final macValidation = MACAddress.validate(mac);
    if (!macValidation.state) {
      throw const WakeOnLanException(
        'Enter a MAC address like AA:BB:CC:DD:EE:FF',
      );
    }

    final ip = ipv4Address.trim().isEmpty ? defaultBroadcast : ipv4Address.trim();
    final ipValidation = IPAddress.validate(ip);
    if (!ipValidation.state) {
      throw const WakeOnLanException('Enter a valid IPv4 broadcast address');
    }

    if (port < 0 || port > 65535) {
      throw const WakeOnLanException('Port must be between 0 and 65535');
    }

    final secureOn = password?.trim();
    if (secureOn != null && secureOn.isNotEmpty) {
      final passwordValidation = SecureONPassword.validate(normalizeMac(secureOn));
      if (!passwordValidation.state) {
        throw const WakeOnLanException(
          'SecureON password must look like a MAC address',
        );
      }
    }

    if (repeat < 1) {
      throw const WakeOnLanException('Send the packet at least once');
    }

    try {
      await _sender(
        macAddress: mac,
        ipv4Address: ip,
        port: port,
        password: (secureOn == null || secureOn.isEmpty)
            ? null
            : normalizeMac(secureOn),
        repeat: repeat,
        repeatDelay: repeatDelay,
      );
    } on SocketException {
      throw const WakeOnLanException(
        'Could not send the wake packet on this network',
      );
    } catch (e) {
      if (e is WakeOnLanException) {
        rethrow;
      }
      throw const WakeOnLanException('Could not send the wake packet.');
    }

    return WakeOnLanResult(
      macAddress: mac,
      ipv4Address: ip,
      port: port,
      repeat: repeat,
    );
  }

  Future<List<WakeOnLanTarget>> loadSavedTargets() async {
    final prefs = await _prefs();
    final raw = prefs.getString(savedTargetsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => WakeOnLanTarget.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<WakeOnLanTarget>> saveTarget(WakeOnLanTarget target) async {
    final mac = normalizeMac(target.macAddress);
    final macValidation = MACAddress.validate(mac);
    if (!macValidation.state) {
      throw const WakeOnLanException(
        'Enter a MAC address like AA:BB:CC:DD:EE:FF',
      );
    }
    final label = target.label.trim().isEmpty ? mac : target.label.trim();
    final normalized = target.copyWith(label: label, macAddress: mac);
    final targets = await loadSavedTargets();
    final next = [
      normalized,
      ...targets.where((item) => normalizeMac(item.macAddress) != mac),
    ];
    await _persist(next);
    return next;
  }

  Future<List<WakeOnLanTarget>> deleteTarget(String macAddress) async {
    final mac = normalizeMac(macAddress);
    final targets = await loadSavedTargets();
    final next =
        targets.where((item) => normalizeMac(item.macAddress) != mac).toList();
    await _persist(next);
    return next;
  }

  Future<void> _persist(List<WakeOnLanTarget> targets) async {
    final prefs = await _prefs();
    await prefs.setString(
      savedTargetsKey,
      jsonEncode(targets.map((item) => item.toJson()).toList()),
    );
  }

  static String normalizeMac(String raw) {
    final hex = raw.toUpperCase().replaceAll(RegExp('[^0-9A-F]'), '');
    if (hex.length != 12) {
      return raw.trim();
    }
    final parts = <String>[];
    for (var i = 0; i < 12; i += 2) {
      parts.add(hex.substring(i, i + 2));
    }
    return parts.join(':');
  }

  static String? broadcastFromIpv4(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) {
      return null;
    }
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
      return null;
    }
    return '${octets[0]}.${octets[1]}.${octets[2]}.255';
  }
}

Future<void> sendWakeOnLanPacket({
  required String macAddress,
  required String ipv4Address,
  int port = WakeOnLanService.defaultPort,
  String? password,
  int repeat = WakeOnLanService.defaultRepeat,
  Duration repeatDelay = const Duration(milliseconds: 200),
}) async {
  final mac = MACAddress(macAddress);
  final ip = IPAddress(ipv4Address);
  final wol = WakeOnLAN(
    ip,
    mac,
    password: (password == null || password.isEmpty)
        ? null
        : SecureONPassword(password),
    port: port,
  );
  await wol.wake(repeat: repeat, repeatDelay: repeatDelay);
}
