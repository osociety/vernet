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
}
