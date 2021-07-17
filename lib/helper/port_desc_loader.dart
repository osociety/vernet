import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vernet/models/port.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Do not put this method inside any class, be it top level function
/// Because this method runs inside isolate.
Future<Map<String, Port>> _parsePortDesc(String json) async {
  Map<String, dynamic> ports = jsonDecode(json);
  Map<String, Port> mPorts = {};
  for (String key in ports.keys) {
    List<dynamic> port = ports[key];
    if (port.length > 0) {
      mPorts[key] = Port.fromJson(port[0]);
    }
  }
  return mPorts;
}

class PortDescLoader {
  final String assetPath;

  PortDescLoader(this.assetPath);

  Future<Map<String, Port>> load() async {
    return rootBundle.loadStructuredData<Map<String, Port>>(this.assetPath,
        (jsonStr) async {
      return compute(_parsePortDesc, jsonStr);
    });
  }
}
