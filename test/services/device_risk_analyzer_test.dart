import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/services/network_analysis/device_risk_analyzer.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';

void main() {
  final l10n = AppLocalizationsEn();

  DeviceData device({
    String address = '192.168.1.42',
    String? mac = '00:03:93:AA:BB:CC',
    String? vendor = 'Apple, Inc.',
    String? type = 'Printer',
    String? openPorts,
    String gatewayIp = '192.168.1.1',
  }) =>
      DeviceData(
        id: 1,
        scanId: 1,
        internetAddress: address,
        macAddress: mac,
        vendorName: vendor,
        deviceType: type,
        openPorts: openPorts,
        currentDeviceIp: '192.168.1.10',
        gatewayIp: gatewayIp,
      );

  DeviceRiskAssessment assess(
    DeviceData subject, {
    Iterable<int> ports = const [],
    bool intermittent = false,
  }) =>
      DeviceRiskAnalyzer.assess(
        subject,
        findings: PortRiskAnalyzer.analyze(ports, l10n: l10n),
        appearsIntermittently: intermittent,
      );

  group('DeviceRiskAnalyzer', () {
    test('keeps a known device with standard ports at low risk', () {
      final result = assess(device(openPorts: '631'));

      expect(result.level, DeviceRiskLevel.low);
      expect(result.reasons, isEmpty);
      expect(result.isLow, isTrue);
    });

    test('treats an unknown device type as medium risk', () {
      final result = assess(device(type: null));

      expect(result.level, DeviceRiskLevel.medium);
      expect(result.reasons, [DeviceRiskReason.unknownDeviceType]);
    });

    test('accepts the type the port heuristics infer for the gateway', () {
      final result = assess(
        device(
          address: '192.168.1.1',
          type: null,
        ),
      );

      expect(result.level, DeviceRiskLevel.low);
    });

    test('raises a critical finding to high risk', () {
      final result = assess(device(openPorts: '23'), ports: [23]);

      expect(result.level, DeviceRiskLevel.high);
      expect(result.reasons, [DeviceRiskReason.vulnerableService]);
    });

    test('raises a warning finding to high risk', () {
      final result = assess(device(openPorts: '21'), ports: [21]);

      expect(result.level, DeviceRiskLevel.high);
      expect(result.reasons, [DeviceRiskReason.vulnerableService]);
    });

    test('treats an alternate service port as an unusual port', () {
      final result = assess(device(openPorts: '8080'), ports: [8080]);

      expect(result.level, DeviceRiskLevel.medium);
      expect(result.reasons, [DeviceRiskReason.unusualPorts]);
    });

    test('treats a port no table names as unusual', () {
      final result = assess(device(openPorts: '9999'));

      expect(result.level, DeviceRiskLevel.medium);
      expect(result.reasons, [DeviceRiskReason.unusualPorts]);
    });

    test('raises a globally administered MAC with no vendor to high risk', () {
      final result = assess(device(vendor: null));

      expect(result.level, DeviceRiskLevel.high);
      expect(result.reasons, [DeviceRiskReason.unknownVendor]);
    });

    test('leaves a locally administered MAC without a vendor alone', () {
      // 02:… has the locally administered bit set, as phones rotate.
      final result = assess(device(mac: '02:00:00:AA:BB:CC', vendor: null));

      expect(result.level, DeviceRiskLevel.low);
    });

    test('leaves a device without a MAC and vendor alone', () {
      final result = assess(device(mac: null, vendor: null));

      expect(result.level, DeviceRiskLevel.low);
    });

    test('raises an intermittent device to high risk', () {
      final result = assess(device(openPorts: '631'), intermittent: true);

      expect(result.level, DeviceRiskLevel.high);
      expect(result.reasons, [DeviceRiskReason.intermittentPresence]);
    });

    test('lists every reason worst first', () {
      final result = assess(
        device(type: null, vendor: null, openPorts: '23,9999'),
        ports: [23],
        intermittent: true,
      );

      expect(result.level, DeviceRiskLevel.high);
      expect(result.reasons, [
        DeviceRiskReason.vulnerableService,
        DeviceRiskReason.unknownVendor,
        DeviceRiskReason.intermittentPresence,
        DeviceRiskReason.unknownDeviceType,
        DeviceRiskReason.unusualPorts,
      ]);
    });
  });

  group('device identity checks', () {
    test('the device running the app always has a known type', () {
      const subject = DeviceData(
        id: 1,
        scanId: 1,
        internetAddress: '192.168.1.10',
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
      );

      expect(DeviceRiskAnalyzer.hasKnownDeviceType(subject), isTrue);
    });

    test('an empty or placeholder type is unknown', () {
      expect(
        DeviceRiskAnalyzer.hasKnownDeviceType(device(type: 'Unknown Device')),
        isFalse,
      );
      expect(DeviceRiskAnalyzer.hasKnownDeviceType(device(type: ' ')), isFalse);
    });
  });
}
