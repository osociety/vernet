import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/strings.dart';

class ReverseDNSPage extends StatefulWidget {
  const ReverseDNSPage({super.key});

  @override
  _ReverseDNSPageState createState() => _ReverseDNSPageState();
}

class _ReverseDNSPageState extends BasePage<ReverseDNSPage> {
  String? _hostname;
  @override
  Widget buildPopularChips() {
    return const SizedBox();
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_hostname == null) {
      return const Center(
        child: Text(
          StringValue.reverseDnsLookupEmptyPlaceholder,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: GestureDetector(
        child: Text(
          _hostname!,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        onTap: () {
          Clipboard.setData(ClipboardData(text: _hostname!));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device name copied'),
            ),
          );
        },
      ),
    );
  }

  @override
  String buttonLabel() {
    return 'Find name';
  }

  @override
  String fieldLabel() {
    return 'Enter a device address';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<void> onPressed() async {
    setState(() {
      _hostname = null;
    });
    final String input = textEditingController.text;
    final InternetAddress? lookupAddress = InternetAddress.tryParse(input);
    if (lookupAddress != null) {
      try {
        if (globals.testingActive) {
          setState(() {
            _hostname = 'maa03s29-in-f14.1e100.net';
          });
        } else {
          final InternetAddress address = await lookupAddress.reverse();
          setState(() {
            _hostname = address.host;
          });
        }
      } catch (e) {
        if (e is SocketException) {
          _showMessage(e.message);
        } else {
          _showMessage('We could not find a name for that address');
        }
      }
    } else {
      //Show snackbar with error
      _showMessage('That does not look like a valid device address');
    }
  }

  @override
  String title() {
    return 'Find device name';
  }
}
