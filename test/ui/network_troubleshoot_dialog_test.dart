import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/network_troubleshoot_dialog.dart';

void main() {
  Widget createDialogApp(NetworkConnectionStatus status) {
    return ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: NetworkTroubleshootDialog(status: status),
        ),
      ),
    );
  }

  group('NetworkTroubleshootDialog', () {
    testWidgets('renders connected status with details', (tester) async {
      const status = NetworkConnectionStatus(
        type: NetworkConnectionType.deviceToRouter,
        state: NetworkConnectionState.connected,
        title: 'Device Connected to Router',
        summary: 'Connected via Wi-Fi',
        description: 'Your device has a valid local IP address.',
        details: {
          'Device IP': '192.168.1.5',
          'Gateway IP': '192.168.1.1',
        },
      );

      await tester.pumpWidget(createDialogApp(status));

      expect(find.text('Device Connected to Router'), findsOneWidget);
      expect(find.text('Connected via Wi-Fi'), findsOneWidget);
      expect(find.text('Your device has a valid local IP address.'), findsOneWidget);
      expect(find.text('Device IP'), findsOneWidget);
      expect(find.text('192.168.1.5'), findsOneWidget);
      expect(find.text('Gateway IP'), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders disconnected status with troubleshooting steps',
        (tester) async {
      const status = NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: 'Router Disconnected from Internet',
        summary: 'Unable to reach internet servers',
        description: 'Unable to reach google.com.',
        troubleshootingSteps: [
          'Check broadband cable connected to router.',
          'Restart modem and router.',
        ],
        details: {
          'Target Host': 'google.com',
        },
      );

      await tester.pumpWidget(createDialogApp(status));

      expect(find.text('Router Disconnected from Internet'), findsOneWidget);
      expect(find.text('Unable to reach internet servers'), findsOneWidget);
      expect(find.text('Troubleshooting Steps'), findsOneWidget);
      expect(
        find.text('Check broadband cable connected to router.'),
        findsOneWidget,
      );
      expect(find.text('Restart modem and router.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
