import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/secret_loader.dart';
import 'package:vernet/models/internet_provider.dart';
import 'package:vernet/models/secret.dart';
import 'package:flutter/services.dart' show rootBundle;

class ISPLoader {
  Future<String> loadIP() async {
    String url = 'https://api.ipify.org';
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == HttpStatus.ok) {
      return response.body;
    }
    return '';
  }

  Future<InternetProvider> _mimicLoad() async {
    return rootBundle.loadStructuredData<InternetProvider>('assets/ipify.json',
        (json) async {
      return InternetProvider.fromMap(jsonDecode(json));
    });
  }

  Future<InternetProvider?> load() async {
    if (kDebugMode) return await _mimicLoad();
    SharedPreferences sp = await SharedPreferences.getInstance();
    String _ip = await loadIP();
    if (_ip.isNotEmpty) {
      //Fetch internet provider data
      String? json = sp.getString(_ip);
      if (json != null && json.isNotEmpty) {
        // print('Response fetched from local $json');
        return InternetProvider.fromMap(jsonDecode(json));
      }
    }

    Secret secret = await SecretLoader('assets/secrets.json').load();
    String uri = 'https://geo.ipify.org/api/v1?apiKey=' +
        secret.ipifyKey +
        '&ipAddress=' +
        _ip;
    var response = await http.get(Uri.parse(uri));
    if (response.statusCode == HttpStatus.ok) {
      // print('Response fetched from ipify.org ${response.body}');
      sp.setString(_ip, response.body);
      return InternetProvider.fromMap(jsonDecode(response.body));
    }
    return null;
  }
}
