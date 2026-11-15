import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/globals.dart' as globals;

class ReverseDNSPage extends StatefulWidget {
  const ReverseDNSPage({super.key});

  @override
  _ReverseDNSPageState createState() => _ReverseDNSPageState();
}

class _ReverseDNSPageState extends BasePage<ReverseDNSPage> {
  String? _hostname;
  @override
  Widget buildPopularChips(BuildContext context) {
    return const SizedBox();
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_hostname == null) {
      return Center(
        child: Text(
          context.l10n.reverseDnsLookupEmptyPlaceholder,
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
            SnackBar(
              content: Text(context.l10n.reverseDnsNameCopied),
            ),
          );
        },
      ),
    );
  }

  @override
  String buttonLabel(BuildContext context) {
    return context.l10n.reverseDnsFindName;
  }

  @override
  String fieldLabel(BuildContext context) {
    return context.l10n.reverseDnsFieldHint;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<void> onPressed() async {
    final l10n = context.l10n;
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
          if (!mounted) return;
          setState(() {
            _hostname = address.host;
          });
        }
      } catch (e) {
        if (e is SocketException) {
          _showMessage(e.message);
        } else {
          _showMessage(l10n.reverseDnsNotFound);
        }
      }
    } else {
      _showMessage(l10n.reverseDnsInvalidAddress);
    }
  }

  @override
  String title(BuildContext context) {
    return context.l10n.reverseDnsPageTitle;
  }
}
