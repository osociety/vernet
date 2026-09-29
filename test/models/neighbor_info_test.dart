import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/neighbor_info.dart';

void main() {
  test('hostname prefers sysName then deviceId', () {
    const a = NeighborInfo(protocol: NeighborProtocol.lldp, deviceId: 'aa:bb');
    expect(a.hostname, 'aa:bb');

    const b = NeighborInfo(
      protocol: NeighborProtocol.cdp,
      deviceId: 'id',
      sysName: 'core-sw1',
    );
    expect(b.hostname, 'core-sw1');
  });

  test('switch displayName falls back to IP', () {
    const unnamed = SwitchIdentity(ip: '10.0.0.1');
    expect(unnamed.displayName, '10.0.0.1');
    const named = SwitchIdentity(ip: '10.0.0.1', sysName: 'core-sw1');
    expect(named.displayName, 'core-sw1');
  });
}
