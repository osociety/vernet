import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/repository/wifi_repository.dart';

void main() {
  group('WifiRepository RSSI and Signal Level mappings', () {
    test('convertRssiToLevel maps dBm values properly', () {
      // Level 4 (Excellent): >= -55 dBm
      expect(WifiRepository.convertRssiToLevel(-30), 4);
      expect(WifiRepository.convertRssiToLevel(-50), 4);
      expect(WifiRepository.convertRssiToLevel(-55), 4);

      // Level 3 (Good): >= -67 dBm
      expect(WifiRepository.convertRssiToLevel(-56), 3);
      expect(WifiRepository.convertRssiToLevel(-60), 3);
      expect(WifiRepository.convertRssiToLevel(-67), 3);

      // Level 2 (Fair): >= -78 dBm
      expect(WifiRepository.convertRssiToLevel(-68), 2);
      expect(WifiRepository.convertRssiToLevel(-70), 2);
      expect(WifiRepository.convertRssiToLevel(-78), 2);

      // Level 1 (Weak): >= -90 dBm
      expect(WifiRepository.convertRssiToLevel(-79), 1);
      expect(WifiRepository.convertRssiToLevel(-85), 1);
      expect(WifiRepository.convertRssiToLevel(-90), 1);

      // Level 0 (Disconnected / Critically Low): < -90 dBm
      expect(WifiRepository.convertRssiToLevel(-91), 0);
      expect(WifiRepository.convertRssiToLevel(-100), 0);
    });

    test('getDiagnosticString returns accurate diagnostic descriptions', () {
      expect(WifiRepository.getDiagnosticString(-50), 'Excellent');
      expect(WifiRepository.getDiagnosticString(-55), 'Excellent');
      expect(WifiRepository.getDiagnosticString(-60), 'Good');
      expect(WifiRepository.getDiagnosticString(-67), 'Good');
      expect(WifiRepository.getDiagnosticString(-68), 'Fair');
      expect(WifiRepository.getDiagnosticString(-75), 'Fair');
      expect(WifiRepository.getDiagnosticString(-78), 'Fair');
      expect(WifiRepository.getDiagnosticString(-79), 'Weak');
      expect(WifiRepository.getDiagnosticString(-90), 'Weak');
      expect(
        WifiRepository.getDiagnosticString(-95),
        'Critically Low',
      );
    });
  });

  group('WifiRepository Linux signal sources', () {
    test('dbmFromSignalPercent maps link quality to the dBm window', () {
      expect(WifiRepository.dbmFromSignalPercent(100), -30);
      expect(WifiRepository.dbmFromSignalPercent(77), -46);
      expect(WifiRepository.dbmFromSignalPercent(0), -100);
    });

    test('parseIwInterfaces takes every interface named under its phy', () {
      const output = '''
Wiphy phy0
	wiphy index: 0
	max # scan SSIDs: 4
	Supported interface modes:
		 * managed
	Band 1:
		Capabilities 0x1161
	Interface wlp2s0
		ifindex 3
		wdev 0x1
		addr aa:bb:cc:dd:ee:ff
		type managed
		p2p-dev wlp2s0
		channel 6, channel width 20 MHz
''';

      expect(WifiRepository.parseIwInterfaces(output), ['wlp2s0']);
      expect(
        WifiRepository.parseIwInterfaces('Wiphy phy0\n\tInterface wlan0\n'),
        ['wlan0'],
      );
      expect(WifiRepository.parseIwInterfaces(''), isEmpty);
    });

    test('parseIwLinkOutput reads the signal of the connected network', () {
      const connected = '''
Connected to aa:bb:cc:dd:ee:ff (on wlp2s0)
	SSID: Lab Network
	freq: 2437
	RX: bytes 9876543
		packets 41230
		dropped: 0
	signal: -48 dBm
	Last beacon: 1040ms ago
''';

      expect(WifiRepository.parseIwLinkOutput(connected), -48);
      // iw 3.x and earlier wrote the field without a colon.
      expect(WifiRepository.parseIwLinkOutput('signal -63 dBm'), -63);
      expect(WifiRepository.parseIwLinkOutput('Not connected.'), isNull);
      expect(WifiRepository.parseIwLinkOutput(''), isNull);
    });

    test('parseNmcliWifiListOutput reads only the associated network', () {
      expect(WifiRepository.parseNmcliWifiListOutput('*:77\n:64\n:51\n'), -46);
      expect(WifiRepository.parseNmcliWifiListOutput(':64\n:51\n'), isNull);
      expect(WifiRepository.parseNmcliWifiListOutput('*:\n:64\n'), isNull);
      expect(WifiRepository.parseNmcliWifiListOutput(''), isNull);
    });

    test('parseProcNetWireless reads the level column of the first face', () {
      const lines = [
        'Inter-| sta-|   Quality        |   Discarded packets               | Missed | WE',
        ' face | tus | link level noise |  nwid  frag   retry  misc   miss | nbeacon',
        ' wlp2s0: 0000   74.  -48.  -52        0      0      0      0      0        0',
      ];

      expect(WifiRepository.parseProcNetWireless(lines), -48);
      // A cfg80211 kernel leaves the file header-only, which is not
      // "no signal" and must not be reported as a reading.
      expect(WifiRepository.parseProcNetWireless(lines.sublist(0, 2)), isNull);
      expect(WifiRepository.parseProcNetWireless(const []), isNull);
    });
  });
}
