import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/host_scan_page/widgets/device_distribution_strip.dart';
import 'package:vernet/utils/device_distribution.dart';

DeviceData device(String ip,
    {String currentDeviceIp = '192.168.1.10',
    String gatewayIp = '192.168.1.1'}) {
  return DeviceData(
    id: ip.hashCode,
    internetAddress: ip,
    hostMake: 'host-$ip',
    currentDeviceIp: currentDeviceIp,
    gatewayIp: gatewayIp,
    scanId: 1,
  );
}

Widget host(
    DeviceDistribution distribution, void Function(DeviceData) onDeviceTap) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DeviceDistributionStrip(
          distribution: distribution, onDeviceTap: onDeviceTap),
    ),
  );
}

void main() {
  testWidgets('renders one block per host id 1..254 and the found count',
      (tester) async {
    final distribution = DeviceDistribution.fromDevices([
      device('192.168.1.1'),
      device('192.168.1.42'),
    ]);

    await tester.pumpWidget(host(distribution, (_) {}));

    for (var hostId = 1; hostId <= 254; hostId++) {
      expect(find.byKey(Key('distribution-block-$hostId')), findsOneWidget,
          reason: 'block $hostId');
    }
    expect(find.textContaining('2 of 254'), findsOneWidget);
  });

  testWidgets('tapping a found block opens its device via onDeviceTap',
      (tester) async {
    final router = device('192.168.1.1');
    final laptop = device('192.168.1.42');
    final distribution = DeviceDistribution.fromDevices([router, laptop]);
    DeviceData? tapped;

    await tester.pumpWidget(host(distribution, (d) => tapped = d));
    await tester.tap(find.byKey(const Key('distribution-block-42')));
    await tester.pump();

    expect(tapped, same(laptop));
  });

  testWidgets(
      'tapping an empty block shows the no-device dialog and OK closes it',
      (tester) async {
    final distribution =
        DeviceDistribution.fromDevices([device('192.168.1.42')]);
    DeviceData? tapped;

    await tester.pumpWidget(host(distribution, (d) => tapped = d));
    await tester.tap(find.byKey(const Key('distribution-block-7')));
    await tester.pumpAndSettle();

    expect(tapped, isNull);
    expect(find.text('No device found at 192.168.1.7'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('No device found at 192.168.1.7'), findsNothing);
  });

  testWidgets(
      'found blocks use the primary color, empty blocks the outline color',
      (tester) async {
    final distribution =
        DeviceDistribution.fromDevices([device('192.168.1.42')]);

    await tester.pumpWidget(host(distribution, (_) {}));

    final theme =
        Theme.of(tester.element(find.byType(DeviceDistributionStrip)));
    final foundContainer = tester.widget<Container>(
      find.descendant(
          of: find.byKey(const Key('distribution-block-42')),
          matching: find.byType(Container)),
    );
    final emptyContainer = tester.widget<Container>(
      find.descendant(
          of: find.byKey(const Key('distribution-block-8')),
          matching: find.byType(Container)),
    );
    final decoration = foundContainer.decoration! as BoxDecoration;
    final emptyDecoration = emptyContainer.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.primary);
    expect(emptyDecoration.color, theme.colorScheme.outlineVariant);
  });
}
