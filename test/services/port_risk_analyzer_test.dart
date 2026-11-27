import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/models/network_finding.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('PortRiskAnalyzer', () {
    test('orders findings by severity and explains Telnet first', () {
      final findings = PortRiskAnalyzer.analyze([80, 23, 21], l10n: l10n);

      expect(
        findings.map((finding) => finding.code),
        [
          NetworkFindingCode.telnet,
          NetworkFindingCode.ftp,
          NetworkFindingCode.unencryptedWeb,
        ],
      );
      final telnet = findings.first;
      expect(telnet.severity, NetworkFindingSeverity.critical);
      expect(telnet.port, 23);
      expect(telnet.title, 'Telnet is enabled');
      expect(telnet.description, contains('without encryption'));
    });

    test('treats SMB and NetBIOS as warnings on a LAN scan', () {
      final findings = PortRiskAnalyzer.analyze([139, 445], l10n: l10n);

      expect(findings, hasLength(2));
      expect(
        findings.every(
          (finding) => finding.severity == NetworkFindingSeverity.warning,
        ),
        isTrue,
      );
      expect(findings.map((finding) => finding.code), [
        NetworkFindingCode.netbios,
        NetworkFindingCode.smb,
      ]);
    });

    test('names the database service in the title', () {
      final findings = PortRiskAnalyzer.analyze([3306], l10n: l10n);

      expect(findings.single.title, 'MySQL is reachable');
      expect(findings.single.service, 'MySQL');
    });

    test('does not flag SSH without a version', () {
      expect(PortRiskAnalyzer.analyze([22], l10n: l10n), isEmpty);
    });

    test('warns about an outdated OpenSSH banner', () {
      final findings = PortRiskAnalyzer.analyze(
        [22],
        l10n: l10n,
        sshVersion: 'SSH-2.0-OpenSSH_7.4p1 Debian-10+deb10u2',
      );

      expect(findings.single.code, NetworkFindingCode.outdatedSsh);
      expect(findings.single.severity, NetworkFindingSeverity.warning);
      expect(
        findings.single.description,
        'The server reports OpenSSH 7.4. Vernet recommends OpenSSH 8.0 or '
        'newer.',
      );
    });

    test('accepts a current OpenSSH banner', () {
      expect(
        PortRiskAnalyzer.analyze(
          [22],
          l10n: l10n,
          sshVersion: 'SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5',
        ),
        isEmpty,
      );
    });

    test('ignores a banner from another SSH implementation', () {
      expect(
        PortRiskAnalyzer.analyze(
          [22],
          l10n: l10n,
          sshVersion: 'SSH-2.0-dropbear_2022.83',
        ),
        isEmpty,
      );
    });

    test('mentions alternate ports as possibilities', () {
      final findings = PortRiskAnalyzer.analyze([8080], l10n: l10n);

      expect(findings.single.code, NetworkFindingCode.alternateService);
      expect(findings.single.severity, NetworkFindingSeverity.info);
      expect(findings.single.title, 'Possible HTTP on a non-standard port');
      expect(findings.single.description, contains('Port 8080'));
    });

    test('reports one finding per port however often it is listed', () {
      expect(
        PortRiskAnalyzer.analyze([21, 21, 21], l10n: l10n),
        hasLength(1),
      );
    });

    test('parses the stored comma-separated port list', () {
      expect(
        PortRiskAnalyzer.parsePorts(' 21,abc, 70000,0,22 '),
        [21, 22],
      );
      expect(PortRiskAnalyzer.parsePorts(null), isEmpty);
      expect(PortRiskAnalyzer.parsePorts(''), isEmpty);
    });
  });

  group('OpenSshVersion', () {
    test('reads the major and minor release out of a banner', () {
      final version = OpenSshVersion.parse('SSH-2.0-OpenSSH_10.0p2');

      expect(version, isNotNull);
      expect(version!.major, 10);
      expect(version.minor, 0);
      expect(version.label, 'OpenSSH 10.0');
    });

    test('compares versions by number, not by text', () {
      final version = OpenSshVersion.parse('SSH-2.0-OpenSSH_7.9p1')!;

      expect(version.isOlderThan((8, 0)), isTrue);
      expect(version.isOlderThan((7, 9)), isFalse);
    });

    test('returns null when the banner names no OpenSSH release', () {
      expect(OpenSshVersion.parse('SSH-2.0-dropbear_2022.83'), isNull);
      expect(OpenSshVersion.parse('not a banner'), isNull);
    });
  });
}
