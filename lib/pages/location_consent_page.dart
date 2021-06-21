import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/pages/home_page.dart';

class LocationConsentPage extends StatefulWidget {
  const LocationConsentPage({Key? key}) : super(key: key);

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
                Text(
                  "Vernet",
                  style: Theme.of(context).textTheme.headline1,
                  textAlign: TextAlign.center,
                ),
                Icon(Icons.radar, size: 100),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: 50, right: 50),
                  child: Text(
                    'This app needs location in order to retrieve wifi name only and does not share your location information outside the app.',
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    NetworkInfo _networkInfo = NetworkInfo();
                    if (Platform.isMacOS) {
                      _navigate(context);
                    } else if (Platform.isIOS) {
                      LocationAuthorizationStatus status =
                          await _networkInfo.getLocationServiceAuthorization();
                      if (status == LocationAuthorizationStatus.notDetermined) {
                        status = await _networkInfo
                            .requestLocationServiceAuthorization();
                      }
                      if (status ==
                          LocationAuthorizationStatus.authorizedWhenInUse) {
                        _navigate(context);
                      }
                    } else {
                      Permission.location.request().isGranted.then((value) {
                        if (value) _navigate(context);
                      });
                    }
                  },
                  child: Text('Grant Location Permission'),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _navigate(context);
                  },
                  child: Text('Continue without permission'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _navigate(BuildContext context) {
    ConsentLoader.setConsentPageShown(true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(),
      ),
    );
  }
}
