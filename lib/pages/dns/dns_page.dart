import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/pages/base_page.dart';
import 'package:vernet/store/inline_adaptive_banner.dart';
import 'package:vernet/store/store_ad_slot.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';

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
        ? Center(
            child: Text(
              context.l10n.dnsLookupEmptyPlaceholder,
              textAlign: TextAlign.center,
            ),
          )
        : ListView.builder(
            itemCount: _addresses.length + kStoreBannerRows,
            itemBuilder: (context, index) {
              if (index < kStoreBannerRows) {
                return const InlineAdaptiveBanner(slot: StoreAdSlot.dns);
              }
              final address = _addresses[index - kStoreBannerRows];
              final yes = context.l10n.valueYes;
              final no = context.l10n.valueNo;
              String flag(bool value) => value ? yes : no;
              return AdaptiveListTile(
                key: WidgetKey.dnsResultTile.key,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: address.address),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.dnsAddressCopied),
                    ),
                  );
                },
                title: Text(address.address),
                subtitle: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(context.l10n.dnsAddressType(address.type.name)),
                    Text(
                        context.l10n.dnsIsLinkLocal(flag(address.isLinkLocal))),
                    Text(context.l10n.dnsIsLoopback(flag(address.isLoopback))),
                    Text(
                        context.l10n.dnsIsMulticast(flag(address.isMulticast))),
                  ],
                ),
              );
            },
          );
  }

  @override
  String buttonLabel(BuildContext context) {
    return context.l10n.dnsFindAddresses;
  }

  @override
  String fieldLabel(BuildContext context) {
    return context.l10n.dnsFieldHint;
  }

  @override
  String title(BuildContext context) {
    return context.l10n.dnsPageTitle;
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
