import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/pages/neighbor_discovery_page/neighbor_discovery_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_discovery_service.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

Widget wrap(Widget child) {
  return ChangeNotifierProvider<DarkThemeProvider>(
    create: (_) => DarkThemeProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NeighborDiscoveryPage can be instantiated', () {
    const page = NeighborDiscoveryPage();
    expect(page, isA<NeighborDiscoveryPage>());
  });

  testWidgets('renders SNMP form and CLI paste entry point', (tester) async {
    await tester.pumpWidget(wrap(const NeighborDiscoveryPage(initialSwitchIp: '192.168.1.1')));
    await tester.pump();

    expect(find.text(StringValue.neighborDiscoveryPageTitle), findsOneWidget);
    expect(find.byKey(WidgetKey.neighborSwitchIpField.key), findsOneWidget);
    expect(find.byKey(WidgetKey.neighborDiscoverButton.key), findsOneWidget);
    expect(find.byKey(WidgetKey.neighborCliTile.key), findsOneWidget);
    expect(find.text(StringValue.neighborDiscoveryEmptyPlaceholder), findsOneWidget);
  });

  testWidgets('parses pasted CDP CLI into a neighbor card', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrap(const NeighborDiscoveryPage(initialSwitchIp: '192.168.1.1')));
    await tester.pump();

    await tester.tap(find.byKey(WidgetKey.neighborCliTile.key));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(WidgetKey.neighborCliField.key),
      '''
Device ID: ACCESS-SW1
IP address: 10.0.0.2
Interface: GigabitEthernet1/0/24
Port ID (outgoing port): Gi0/1
Platform: cisco WS-C2960X
Native VLAN: 20
Duplex: full
''',
    );
    await tester.tap(find.byKey(WidgetKey.neighborParseCliButton.key));
    await tester.pumpAndSettle();

    expect(find.text('ACCESS-SW1'), findsOneWidget);
    expect(find.text('Management IP: 10.0.0.2'), findsOneWidget);
    expect(find.text('Switch port: GigabitEthernet1/0/24'), findsOneWidget);
  });

  testWidgets('discovers neighbors via SNMP button and renders switch and neighbor cards', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = FakeDiscoveryService();
    await tester.pumpWidget(
      wrap(NeighborDiscoveryPage(initialSwitchIp: '192.168.1.1', service: service)),
    );
    await tester.pump();

    await tester.tap(find.byKey(WidgetKey.neighborDiscoverButton.key));
    await tester.pumpAndSettle();

    expect(find.text('core-switch-1'), findsOneWidget);
    expect(find.text('ap-floor1'), findsOneWidget);
    expect(find.text('Switch port: Gi1/0/1'), findsOneWidget);
    expect(find.text('Management IP: 192.168.1.50'), findsOneWidget);
    expect(find.text('VLAN 10'), findsOneWidget);
  });
}

class FakeDiscoveryService extends NeighborDiscoveryService {
  @override
  Future<NeighborDiscoveryResult> discover({
    required String switchIp,
    required String community,
    bool queryCdp = true,
    bool queryLldp = true,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return const NeighborDiscoveryResult(
      switchInfo: SwitchIdentity(
        ip: '192.168.1.1',
        sysName: 'core-switch-1',
        sysDescr: 'Cisco IOS Software, C3560 Software',
      ),
      neighbors: [
        NeighborInfo(
          protocol: NeighborProtocol.cdp,
          deviceId: 'ap-floor1',
          sysName: 'ap-floor1',
          managementIp: '192.168.1.50',
          localPort: 'Gi1/0/1',
          remotePort: 'GigabitEthernet0',
          platform: 'cisco AIR-CAP3702I-A-K9',
          vlan: '10',
          speedDuplex: '1 Gbps full',
        ),
      ],
    );
  }
}
