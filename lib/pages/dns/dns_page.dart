import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

class DNSPage extends StatefulWidget {
  const DNSPage({super.key});

  @override
  _DNSPageState createState() => _DNSPageState();
}

class _DNSPageState extends BasePage<DNSPage> {
  List<InternetAddress> _addresses = [];

  @override
  Widget buildResults(BuildContext context) {
    return _addresses.isEmpty
        ? const Center(
            child: Text(
              'No addresses found yet.\nAll addresses will appear here.',
              textAlign: TextAlign.center,
            ),
          )
        : ListView.builder(
            itemCount: _addresses.length,
            itemBuilder: (context, index) {
              return AdaptiveListTile(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: _addresses[index].address),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('IP copied to clipboard'),
                    ),
                  );
                },
                title: Text(_addresses[index].address),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Type: ${_addresses[index].type.name},'),
                    Text('Local link: ${_addresses[index].isLinkLocal},'),
                    Text('Loopback: ${_addresses[index].isLoopback},'),
                    Text('Multicast: ${_addresses[index].isMulticast}'),
                  ],
                ),
              );
            },
          );
  }

  @override
  String buttonLabel() {
    return 'Lookup';
  }

  @override
  String fieldLabel() {
    return 'Enter domain name';
  }

  @override
  String title() {
    return 'DNS Lookup';
  }

  @override
  Future<void> onPressed() async {
    setState(() {
      _addresses.clear();
    });
    final List<InternetAddress> addresses =
        await InternetAddress.lookup(textEditingController.text);

    setState(() {
      _addresses = addresses;
    });
  }
}
