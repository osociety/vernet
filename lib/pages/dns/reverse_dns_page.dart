import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';

class ReverseDNSPage extends StatefulWidget {
  const ReverseDNSPage({Key? key}) : super(key: key);

  @override
  _ReverseDNSPageState createState() => _ReverseDNSPageState();
}

class _ReverseDNSPageState extends BasePage<ReverseDNSPage> {
  InternetAddress? _address;
  @override
  Widget buildPopularChips() {
    return SizedBox();
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_address == null) {
      return Center(
        child: Text(
          'Host name not found yet.\nHost name will appear here.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: Container(
        child: GestureDetector(
          child: Text(
            '${_address!.host}',
            style: Theme.of(context).textTheme.headline5,
          ),
          onTap: () {
            Clipboard.setData(ClipboardData(text: _address!.host));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Name copied to clipboard"),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  String buttonLabel() {
    return 'Lookup';
  }

  @override
  String fieldLabel() {
    return 'Enter IPv4 or IPv6 address';
  }

  _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<void> onPressed() async {
    setState(() {
      _address = null;
    });
    String input = textEditingController.text;
    InternetAddress? lookupAddress = InternetAddress.tryParse(input);
    if (lookupAddress != null) {
      try {
        InternetAddress address = await lookupAddress.reverse();
        setState(() {
          _address = address;
        });
      } catch (e) {
        if (e is SocketException) {
          _showMessage('${e.message}');
        } else {
          _showMessage('Unable to lookup');
        }
      }
    } else {
      //Show snackbar with error
      _showMessage('Address is not in valid IPv4 or IPv6 format');
    }
  }

  @override
  String title() {
    return 'Reverse DNS Lookup';
  }
}
