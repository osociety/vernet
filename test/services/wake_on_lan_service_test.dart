import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/wake_on_lan_target.dart';
import 'package:vernet/services/wake_on_lan_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake sender that just records calls without touching UDP sockets.
Future<void> _fakeSender({
  required String macAddress,
  required String ipv4Address,
  int port = WakeOnLanService.defaultPort,
  String? password,
  int repeat = WakeOnLanService.defaultRepeat,
  Duration repeatDelay = const Duration(milliseconds: 200),
}) async {
  // no-op – succeeds silently
}

/// A fake sender that always throws a [WakeOnLanException].
Future<void> _failingSender({
  required String macAddress,
  required String ipv4Address,
  int port = WakeOnLanService.defaultPort,
  String? password,
  int repeat = WakeOnLanService.defaultRepeat,
  Duration repeatDelay = const Duration(milliseconds: 200),
}) {
  throw const WakeOnLanException('network error');
}

WakeOnLanService _makeService({
  WakeOnLanSender? sender,
  Map<String, Object>? prefs,
}) {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  return WakeOnLanService(
    sender: sender ?? _fakeSender,
    prefs: SharedPreferences.getInstance,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── normalizeMac ──────────────────────────────────────────────────────────
  group('normalizeMac', () {
    test('already colon-separated upper is unchanged', () {
      expect(
        WakeOnLanService.normalizeMac('AA:BB:CC:DD:EE:FF'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('lowercase letters are uppercased', () {
      expect(
        WakeOnLanService.normalizeMac('aa:bb:cc:dd:ee:ff'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('dashes are treated as separators', () {
      expect(
        WakeOnLanService.normalizeMac('AA-BB-CC-DD-EE-FF'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('no separator still works', () {
      expect(
        WakeOnLanService.normalizeMac('AABBCCDDEEFF'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('short value is returned as-is trimmed', () {
      expect(WakeOnLanService.normalizeMac('short'), 'short');
    });
  });

  // ── broadcastFromIpv4 ─────────────────────────────────────────────────────
  group('broadcastFromIpv4', () {
    test('replaces last octet with 255', () {
      expect(
        WakeOnLanService.broadcastFromIpv4('192.168.1.100'),
        '192.168.1.255',
      );
    });

    test('already .255 address is returned unchanged', () {
      expect(
        WakeOnLanService.broadcastFromIpv4('10.0.0.255'),
        '10.0.0.255',
      );
    });

    test('returns null for invalid IP', () {
      expect(WakeOnLanService.broadcastFromIpv4('not-an-ip'), isNull);
    });

    test('returns null when too few octets', () {
      expect(WakeOnLanService.broadcastFromIpv4('192.168.1'), isNull);
    });
  });

  // ── wake – validation ─────────────────────────────────────────────────────
  group('wake – validation', () {
    late WakeOnLanService service;

    setUp(() => service = _makeService());

    test('throws on invalid MAC', () {
      expect(
        () => service.wake(macAddress: 'bad-mac'),
        throwsA(
          isA<WakeOnLanException>().having(
            (e) => e.message,
            'message',
            contains('MAC'),
          ),
        ),
      );
    });

    test('throws on invalid IP', () {
      expect(
        () => service.wake(
          macAddress: 'AA:BB:CC:DD:EE:FF',
          ipv4Address: 'not-an-ip',
        ),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('throws on port out of range', () {
      expect(
        () => service.wake(
          macAddress: 'AA:BB:CC:DD:EE:FF',
          port: 99999,
        ),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('throws when repeat < 1', () {
      expect(
        () => service.wake(
          macAddress: 'AA:BB:CC:DD:EE:FF',
          repeat: 0,
        ),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('throws on bad SecureON password', () {
      expect(
        () => service.wake(
          macAddress: 'AA:BB:CC:DD:EE:FF',
          password: 'not-a-password',
        ),
        throwsA(isA<WakeOnLanException>()),
      );
    });
  });

  // ── wake – success ────────────────────────────────────────────────────────
  group('wake – success', () {
    test('returns WakeOnLanResult with normalised MAC', () async {
      final service = _makeService(sender: _fakeSender);
      final result = await service.wake(macAddress: 'aabbccddeeff');

      expect(result.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(result.ipv4Address, WakeOnLanService.defaultBroadcast);
      expect(result.port, WakeOnLanService.defaultPort);
      expect(result.repeat, WakeOnLanService.defaultRepeat);
    });

    test('empty ipv4Address falls back to broadcast', () async {
      final service = _makeService(sender: _fakeSender);
      final result = await service.wake(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        ipv4Address: '',
      );
      expect(result.ipv4Address, WakeOnLanService.defaultBroadcast);
    });

    test('valid SecureON password is accepted', () async {
      final service = _makeService(sender: _fakeSender);
      final result = await service.wake(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        password: '00:11:22:33:44:55',
      );
      expect(result.macAddress, 'AA:BB:CC:DD:EE:FF');
    });
  });

  // ── wake – sender failures ────────────────────────────────────────────────
  group('wake – sender failure', () {
    test('WakeOnLanException from sender is re-thrown', () {
      final service = _makeService(sender: _failingSender);
      expect(
        () => service.wake(macAddress: 'AA:BB:CC:DD:EE:FF'),
        throwsA(isA<WakeOnLanException>()),
      );
    });
  });

  // ── saved targets ─────────────────────────────────────────────────────────
  group('saved targets', () {
    test('loadSavedTargets returns empty list when nothing persisted',
        () async {
      final service = _makeService();
      expect(await service.loadSavedTargets(), isEmpty);
    });

    test('saveTarget persists and returns the new target first', () async {
      final service = _makeService();
      const target = WakeOnLanTarget(
        label: 'My PC',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );
      final saved = await service.saveTarget(target);
      expect(saved, hasLength(1));
      expect(saved.first.label, 'My PC');
      expect(saved.first.macAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('saving same MAC twice replaces the entry', () async {
      final service = _makeService();
      await service.saveTarget(
        const WakeOnLanTarget(
          label: 'Old Label',
          macAddress: 'AA:BB:CC:DD:EE:FF',
        ),
      );
      final saved = await service.saveTarget(
        const WakeOnLanTarget(
          label: 'New Label',
          macAddress: 'AA:BB:CC:DD:EE:FF',
        ),
      );
      expect(saved, hasLength(1));
      expect(saved.first.label, 'New Label');
    });

    test('saveTarget throws on invalid MAC', () {
      final service = _makeService();
      expect(
        () => service.saveTarget(
          const WakeOnLanTarget(label: 'x', macAddress: 'bad'),
        ),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('label defaults to MAC when empty', () async {
      final service = _makeService();
      final saved = await service.saveTarget(
        const WakeOnLanTarget(label: '', macAddress: 'AA:BB:CC:DD:EE:FF'),
      );
      expect(saved.first.label, 'AA:BB:CC:DD:EE:FF');
    });

    test('deleteTarget removes the right entry', () async {
      final service = _makeService();
      await service.saveTarget(
        const WakeOnLanTarget(label: 'A', macAddress: 'AA:BB:CC:DD:EE:FF'),
      );
      await service.saveTarget(
        const WakeOnLanTarget(label: 'B', macAddress: '11:22:33:44:55:66'),
      );
      final remaining = await service.deleteTarget('AA:BB:CC:DD:EE:FF');
      expect(remaining, hasLength(1));
      expect(remaining.first.macAddress, '11:22:33:44:55:66');
    });

    test('deleteTarget on unknown MAC leaves list unchanged', () async {
      final service = _makeService();
      await service.saveTarget(
        const WakeOnLanTarget(label: 'A', macAddress: 'AA:BB:CC:DD:EE:FF'),
      );
      final remaining = await service.deleteTarget('00:00:00:00:00:00');
      expect(remaining, hasLength(1));
    });

    test('loadSavedTargets survives corrupt prefs gracefully', () async {
      SharedPreferences.setMockInitialValues(
        {WakeOnLanService.savedTargetsKey: '{not-an-array}'},
      );
      final service = WakeOnLanService(
        sender: _fakeSender,
        prefs: SharedPreferences.getInstance,
      );
      expect(await service.loadSavedTargets(), isEmpty);
    });
  });

  // ── WakeOnLanTarget model ─────────────────────────────────────────────────
  group('WakeOnLanTarget', () {
    test('toJson / fromJson round-trip', () {
      const original = WakeOnLanTarget(
        label: 'Gaming Rig',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        ipv4Address: '192.168.1.255',
        port: 7,
        password: '00:11:22:33:44:55',
      );
      final json = original.toJson();
      final restored = WakeOnLanTarget.fromJson(json);

      expect(restored.label, original.label);
      expect(restored.macAddress, original.macAddress);
      expect(restored.ipv4Address, original.ipv4Address);
      expect(restored.port, original.port);
      expect(restored.password, original.password);
    });

    test('copyWith overrides only specified fields', () {
      const original = WakeOnLanTarget(
        label: 'Old',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );
      final copy = original.copyWith(label: 'New');
      expect(copy.label, 'New');
      expect(copy.macAddress, original.macAddress);
      expect(copy.port, original.port);
    });
  });

  // ── WakeOnLanException ────────────────────────────────────────────────────
  group('WakeOnLanException', () {
    test('toString returns message', () {
      const ex = WakeOnLanException('oops');
      expect(ex.toString(), 'oops');
      expect(ex.message, 'oops');
    });
  });
}
