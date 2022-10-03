import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/main.dart';

class LocationConsentPage extends StatefulWidget {
  const LocationConsentPage({super.key});

  @override
  _LocationConsentPageState createState() => _LocationConsentPageState();
}

class _LocationConsentPageState extends State<LocationConsentPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: MediaQuery.of(context).padding,
            child: Column(
              children: [
                const Text('Made with ❤️ in India'),
                const SizedBox(height: 15),
                Text(
                  'Vernet',
                  style: Theme.of(context).textTheme.headline1,
                  textAlign: TextAlign.center,
                ),
                const Icon(Icons.radar, size: 100),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 50, right: 50),
                  child: Text(
                    'This app needs location in order to retrieve wifi name '
                    'only and does not share your location information '
                    'outside the app.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    final NetworkInfo networkInfo = NetworkInfo();
                    if (Platform.isMacOS ||
                        Platform.isLinux ||
                        Platform.isWindows) {
                      _navigate(context);
                    } else if (Platform.isIOS) {
                      LocationAuthorizationStatus status =
                          await networkInfo.getLocationServiceAuthorization();
                      if (status == LocationAuthorizationStatus.notDetermined) {
                        status = await networkInfo
                            .requestLocationServiceAuthorization();
                      }
                      if (status ==
                          LocationAuthorizationStatus.authorizedWhenInUse) {
                        _navigate(context);
                      }
                    } else if (Platform.isAndroid) {
                      Permission.location.request().isGranted.then((value) {
                        if (value) _navigate(context);
                      });
                    }
                  },
                  child: const Text('Grant Location Permission'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _navigate(context);
                  },
                  child: const Text('Continue without permission'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    ConsentLoader.setConsentPageShown(true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const TabBarPage(),
      ),
    );
  }
}
