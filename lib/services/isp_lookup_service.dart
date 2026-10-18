import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves an ISP name when the speed-test configuration omits it.
class IspLookupService {
  IspLookupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> lookup(String ipAddress) async {
    if (ipAddress.isEmpty || ipAddress == 'x.x.x.x') return null;

    try {
      final uri = Uri.https('ipwho.is', ipAddress);
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode != 200) {
        debugPrint('ISP fallback lookup returned HTTP ${response.statusCode}.');
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> || payload['success'] != true) {
        debugPrint('ISP fallback lookup returned no successful result.');
        return null;
      }
      final connection = payload['connection'];
      if (connection is! Map<String, dynamic>) {
        debugPrint('ISP fallback lookup response has no connection data.');
        return null;
      }

      final organization = _usableName(connection['org']);
      final isp = organization ?? _usableName(connection['isp']);
      if (isp == null) {
        debugPrint('ISP fallback lookup returned no ISP name.');
        return null;
      }
      return isp;
    } catch (error) {
      debugPrint('ISP fallback lookup failed: $error');
      return null;
    }
  }

  String? _usableName(dynamic value) {
    final name = value?.toString().trim();
    if (name == null || name.isEmpty || name.toLowerCase() == 'unknown') {
      return null;
    }
    return name;
  }
}
