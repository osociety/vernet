import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

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
              StringValue.dnsLookupEmptyPlaceholder,
              textAlign: TextAlign.center,
            ),
          )
        : ListView.builder(
            itemCount: _addresses.length,
            itemBuilder: (context, index) {
              return AdaptiveListTile(
                key: WidgetKey.dnsResultTile.key,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: _addresses[index].address),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Website address copied'),
                    ),
                  );
                },
                title: Text(_addresses[index].address),
                subtitle: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('Address type: ${_addresses[index].type.name},'),
                    Text(
                        'Local network address: ${_addresses[index].isLinkLocal},'),
                    Text('This device: ${_addresses[index].isLoopback},'),
                    Text('Group address: ${_addresses[index].isMulticast}'),
                  ],
                ),
              );
            },
          );
  }

  @override
  String buttonLabel() {
    return 'Find addresses';
  }

  @override
  String fieldLabel() {
    return 'Enter a website name';
  }

  @override
  String title() {
    return 'Find website addresses';
  }

  @override
  Future<void> onPressed() async {
    setState(() {
      _addresses.clear();
    });
    final List<InternetAddress> addresses =
        await InternetAddress.lookup(textEditingController.text);

    if (!mounted) return;
    setState(() {
      _addresses = addresses;
    });
  }
}
