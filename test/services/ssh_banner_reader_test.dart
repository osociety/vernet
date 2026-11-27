import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/network_analysis/ssh_banner_reader.dart';

void main() {
  group('SshBannerReader', () {
    test('returns the first banner line from a local server', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = <Socket>[];
      server.listen((socket) {
        accepted.add(socket);
        socket.add(utf8.encode('SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5\r\n'));
      });
      addTearDown(() async {
        for (final socket in accepted) {
          socket.destroy();
        }
        await server.close();
      });

      final reader = SshBannerReader(timeout: const Duration(seconds: 1));

      expect(
        await reader.readVersion('127.0.0.1', port: server.port),
        'SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5',
      );
    });

    test('ignores a first line that is not an SSH banner', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = <Socket>[];
      server.listen((socket) {
        accepted.add(socket);
        socket.add(utf8.encode('HELLO\r\n'));
      });
      addTearDown(() async {
        for (final socket in accepted) {
          socket.destroy();
        }
        await server.close();
      });

      final reader = SshBannerReader(timeout: const Duration(seconds: 1));

      expect(await reader.readVersion('127.0.0.1', port: server.port), isNull);
    });

    test('returns null when the connection fails', () async {
      final reader = SshBannerReader(
        connect: (host, port, {timeout}) =>
            Future.error(const SocketException('refused')),
      );

      expect(await reader.readVersion('127.0.0.1'), isNull);
    });
  });
}
