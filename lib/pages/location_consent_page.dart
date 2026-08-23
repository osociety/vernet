import 'dart:io';

import 'package:flutter/material.dart';
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
                const SizedBox(height: 40),
                const Text('Made with ❤️ in India'),
                const SizedBox(height: 15),
                Text(
                  'Vernet',
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const Icon(Icons.radar, size: 100),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 50, right: 50),
                  child: Text(
                    'Location access lets the app show the name of your Wi-Fi '
                    'network. Your location is not shared outside the app.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _grantLocationPermission(context);
                  },
                  child: const Text('Allow location access'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _navigate(context);
                  },
                  child: const Text('Continue without it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _grantLocationPermission(BuildContext context) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
      final value = await Permission.location.request().isGranted;
      if (value) {
        _navigate(context);
      } else {
        return;
      }
    }
    _navigate(context);
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
