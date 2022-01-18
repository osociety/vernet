import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/internet_provider.dart';

class ISPLoader {
  static Future<String> loadIP(String url) async {
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == HttpStatus.ok) {
      return response.body;
    }
    return '';
  }

  Future<InternetProvider> _mimicLoad() async {
    return rootBundle.loadStructuredData<InternetProvider>(
        'assets/ipwhois.json', (json) async {
      return InternetProvider.fromMap(jsonDecode(json) as Map<String, dynamic>);
    });
  }

  static Future<String> loadISP(String url) async {
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == HttpStatus.ok) {
      return response.body;
    }
    return '';
  }

  Future<InternetProvider?> load() async {
    if (kDebugMode) return await _mimicLoad();
    SharedPreferences sp = await SharedPreferences.getInstance();
    String _ip = await compute(loadIP, 'https://api.ipify.org');
    if (_ip.isNotEmpty) {
      //Fetch internet provider data
      String? json = sp.getString(_ip);
      if (json != null && json.isNotEmpty) {
        // print('Response fetched from local $json');
        return InternetProvider.fromMap(
            jsonDecode(json) as Map<String, dynamic>);
      }
    }

    // Secret secret = await SecretLoader('assets/secrets.json').load();
    String url =
        'http://ipwhois.app/json/$_ip?objects=isp,country,region,city,latitude,longitude,country_flag,ip,type';

    String body = await compute(loadISP, url);
    if (body.isNotEmpty) {
      sp.setString(_ip, body);
      return InternetProvider.fromMap(jsonDecode(body) as Map<String, dynamic>);
    }
    return null;
  }
}
