import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/internet_provider.dart';

class ISPLoader {
  static Future<String> loadIP(String url) async {
    final response = await http.get(Uri.parse(url));
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
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == HttpStatus.ok) {
      return response.body;
    }
    return '';
  }

  Future<InternetProvider?> load() async {
    if (kDebugMode) {
      return _mimicLoad();
    }
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final String ip = await compute(loadIP, 'https://api.ipify.org');
    if (ip.isNotEmpty) {
      //Fetch internet provider data
      final String? json = sp.getString(ip);
      if (json != null && json.isNotEmpty) {
        // print('Response fetched from local $json');
        return InternetProvider.fromMap(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
    }

    // Secret secret = await SecretLoader('assets/secrets.json').load();
    final String url =
        'http://ipwhois.app/json/$ip?objects=isp,country,region,city,latitude,longitude,country_flag,ip,type';

    final String body = await compute(loadISP, url);
    if (body.isNotEmpty) {
      sp.setString(ip, body);
      return InternetProvider.fromMap(jsonDecode(body) as Map<String, dynamic>);
    }
    return null;
  }
}
