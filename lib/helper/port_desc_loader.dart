import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vernet/models/port.dart';

/// Do not put this method inside any class, be it top level function
/// Because this method runs inside isolate.
Future<Map<String, Port>> _parsePortDesc(String json) async {
  final Map<String, dynamic> ports = jsonDecode(json) as Map<String, dynamic>;
  final Map<String, Port> mPorts = {};
  for (final String key in ports.keys) {
    final List<dynamic> port = ports[key] as List<dynamic>;
    if (port.isNotEmpty) {
      mPorts[key] = Port.fromJson(port[0]);
    }
  }
  return mPorts;
}

class PortDescLoader {
  PortDescLoader(this.assetPath);

  final String assetPath;

  Future<Map<String, Port>> load() async {
    return await rootBundle.loadStructuredData<Map<String, Port>>(assetPath,
        (jsonStr) async {
      return await compute(_parsePortDesc, jsonStr);
    });
  }
}
