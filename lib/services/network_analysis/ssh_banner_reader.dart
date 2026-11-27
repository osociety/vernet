import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

typedef SocketConnector = Future<Socket> Function(
  String host,
  int port, {
  Duration? timeout,
});

/// Reads the version line an SSH server sends before the client says anything.
///
/// Only used when a device detail page is open, never during discovery: the
/// banner read is a second connection, and a host scan should not pay for it
/// on every device it finds.
@injectable
class SshBannerReader {
  SshBannerReader({
    @ignoreParam this.timeout = const Duration(milliseconds: 800),
    @ignoreParam SocketConnector? connect,
  }) : _connect = connect ?? Socket.connect;

  final Duration timeout;
  final SocketConnector _connect;

  /// The first protocol line, or null when the host does not answer with one.
  Future<String?> readVersion(String host, {int port = 22}) async {
    Socket? socket;
    try {
      socket = await _connect(host, port, timeout: timeout);
      final chunk = await socket.first.timeout(timeout);
      final banner = utf8.decode(chunk, allowMalformed: true);
      final line = banner.split('\n').first.trim();
      return line.startsWith('SSH-') ? line : null;
    } on Object catch (error) {
      debugPrint('SSH banner read failed for $host:$port: $error');
      return null;
    } finally {
      socket?.destroy();
    }
  }
}
