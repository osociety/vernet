import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';

class ReverseDNSPage extends StatefulWidget {
  const ReverseDNSPage({super.key});

  @override
  _ReverseDNSPageState createState() => _ReverseDNSPageState();
}

class _ReverseDNSPageState extends BasePage<ReverseDNSPage> {
  InternetAddress? _address;
  @override
  Widget buildPopularChips() {
    return const SizedBox();
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_address == null) {
      return const Center(
        child: Text(
          'Host name not found yet.\nHost name will appear here.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: GestureDetector(
        child: Text(
          _address!.host,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        onTap: () {
          Clipboard.setData(ClipboardData(text: _address!.host));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name copied to clipboard'),
            ),
          );
        },
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<void> onPressed() async {
    setState(() {
      _address = null;
    });
    final String input = textEditingController.text;
    final InternetAddress? lookupAddress = InternetAddress.tryParse(input);
    if (lookupAddress != null) {
      try {
        final InternetAddress address = await lookupAddress.reverse();
        setState(() {
          _address = address;
        });
      } catch (e) {
        if (e is SocketException) {
          _showMessage(e.message);
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
