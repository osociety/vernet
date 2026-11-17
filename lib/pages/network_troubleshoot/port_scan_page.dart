import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/port.dart';
import 'package:vernet/store/inline_adaptive_banner.dart';
import 'package:vernet/store/store_ad_slot.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';
import 'package:vernet/ui/custom_tile.dart';
import 'package:vernet/ui/popular_chip.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';

class PortScanPage extends StatefulWidget {
  const PortScanPage({this.target = '', this.runDefaultScan = false});

  final String target;
  final bool runDefaultScan;

  /// Strips square brackets and surrounding whitespace from a target address
  /// so IPv6 literals like `[2001:db8::1]` are passed correctly to the scanner.
  static String normalizeTarget(String input) =>
      input.trim().replaceAll('[', '').replaceAll(']', '');

  @override
  _PortScanPageState createState() => _PortScanPageState();
}

enum ScanType { single, top, range }

class _PortScanPageState extends State<PortScanPage>
    with SingleTickerProviderStateMixin {
  final Set<OpenPort> _openPorts = {};

  final TextEditingController _targetIPEditingController =
      TextEditingController();
  final TextEditingController _singlePortEditingController =
      TextEditingController();
  final TextEditingController _startPortEditingController =
      TextEditingController();
  final TextEditingController _endPortEditingController =
      TextEditingController();
  late TabController _tabController;

  /// The tabs only name the three scan modes, so the controller can be built
  /// from a fixed count while the labels come from the resource bundle.
  static const int _tabCount = 3;

  List<Tab> _tabs(AppLocalizations l10n) => [
        Tab(text: l10n.portScanTabWebsites),
        Tab(text: l10n.portScanTabRanges),
        Tab(text: l10n.portScanTabServices),
      ];
  final _formKey = GlobalKey<FormState>();

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleEvent(ActiveHost? host) {
    if (!mounted) return;
    if (host != null) {
      debugPrint('Found open port : ${host.openPorts}');
      setState(() {
        _openPorts.addAll(host.openPorts);
      });
    }
  }

  void _handleOnDone() {
    if (!mounted) return;
    setState(() {
      _completed = true;
    });
    if (_completed && _openPorts.isEmpty) {
      _showSnackBar(context.l10n.portScanNoneFoundSnackbar);
    }
    debugPrint(
      _completed && _openPorts.isEmpty
          ? 'Security check found no reachable services'
          : 'Security check complete',
    );
  }

  StreamSubscription<ActiveHost>? _streamSubscription;
  bool _completed = true;

  void _startScanning() {
    setState(() {
      _completed = false;
      _openPorts.clear();
    });
    final target =
        PortScanPage.normalizeTarget(_targetIPEditingController.text);
    if (_type == ScanType.single) {
      PortScannerService.instance
          .isOpen(
        target,
        int.parse(_singlePortEditingController.text),
      )
          .then((value) {
        _handleEvent(value);
        _handleOnDone();
      });
    } else if (_type == ScanType.top) {
      _streamSubscription = PortScannerService.instance
          .customDiscover(
            target,
            timeout: Duration(milliseconds: appSettings.socketTimeout),
            async: true,
          )
          .listen(_handleEvent, onDone: _handleOnDone);
    } else {
      _streamSubscription = PortScannerService.instance
          .scanPortsForSingleDevice(
            target,
            startPort: int.parse(_startPortEditingController.text),
            endPort: int.parse(_endPortEditingController.text),
            timeout: Duration(milliseconds: appSettings.socketTimeout),
            async: true,
          )
          .listen(_handleEvent, onDone: _handleOnDone);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _targetIPEditingController.text = widget.target;
    if (widget.runDefaultScan) {
      Future.delayed(Durations.short2, _startScanning);
    }
  }

  ScanType? _type = ScanType.top;

  @override
  void dispose() {
    super.dispose();
    _targetIPEditingController.dispose();
    _singlePortEditingController.dispose();
    _endPortEditingController.dispose();
    _startPortEditingController.dispose();
    _tabController.dispose();
    _streamSubscription?.cancel();
  }

  Widget _getCustomRangeChip(Key key, String label, String start, String end) {
    return PopularChip(
      key: key,
      label: label,
      onPressed: () {
        _startPortEditingController.text = start;
        _endPortEditingController.text = end;
      },
    );
  }

  Widget _getSinglePortChip(String label, String port) {
    return PopularChip(
      label: label,
      onPressed: () {
        _singlePortEditingController.text = port;
      },
    );
  }

  Widget _getDomainChip(Key key, String label) {
    return PopularChip(
      key: key,
      label: label,
      onPressed: () {
        _targetIPEditingController.text = label;
      },
    );
  }

  Widget _getFields() {
    if (_type == ScanType.single) {
      return TextFormField(
        key: WidgetKey.enterPortTextField.key,
        keyboardType: TextInputType.number,
        validator: validatePorts,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: _singlePortEditingController,
        decoration: InputDecoration(
          filled: true,
          hintText: context.l10n.portScanHintServiceNumber,
        ),
      );
    } else if (_type == ScanType.range) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              validator: validatePorts,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _startPortEditingController,
              decoration: InputDecoration(
                filled: true,
                hintText: context.l10n.portScanHintFirstServiceNumber,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              validator: validatePorts,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _endPortEditingController,
              decoration: InputDecoration(
                filled: true,
                hintText: context.l10n.portScanHintLastServiceNumber,
              ),
            ),
          ),
        ],
      );
    }
    return const Text('');
  }

  String? validatePorts(String? value) {
    final l10n = context.l10n;
    if (value != null) {
      if (value.isEmpty) return l10n.portScanErrorServiceNumberEmpty;
      try {
        final int port = int.parse(value.trim());
        if (port < 0 || port > 65535) {
          return l10n.portScanErrorServiceNumberRange;
        }
      } catch (e) {
        return l10n.portScanErrorNotANumber;
      }
    }
    return null;
  }

  String? validateIP(String? value) {
    if (value != null) {
      if (value.isEmpty) return context.l10n.portScanErrorTargetEmpty;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.portScanTitle),
      ),
      body: SafeArea(
          child: FutureBuilder<Map<String, Port>>(
        future: PortDescLoader('assets/ports_lists.json').load(),
        builder: (
          BuildContext context,
          AsyncSnapshot<Map<String, Port>> snapshot,
        ) {
          if (snapshot.hasData) {
            final Map<String, Port> allPorts =
                snapshot.data ?? <String, Port>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Container(
                    padding: const EdgeInsets.all(5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  validator: validateIP,
                                  controller: _targetIPEditingController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    hintText: l10n.portScanHintTarget,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              if (_type != ScanType.top)
                                Expanded(child: _getFields())
                              else
                                const SizedBox(),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTile(
                                leading: AdaptiveRadioButton<ScanType>(
                                  value: ScanType.top,
                                  groupValue: _type,
                                  onChanged: (ScanType? value) {
                                    _tabController.index = 0;
                                    setState(() {
                                      _type = value;
                                    });
                                  },
                                ),
                                child: Text(l10n.portScanTabServices),
                              ),
                            ),
                            Expanded(
                              child: CustomTile(
                                leading: AdaptiveRadioButton<ScanType>(
                                  key: WidgetKey.rangePortScanRadioButton.key,
                                  value: ScanType.range,
                                  groupValue: _type,
                                  onChanged: (ScanType? value) {
                                    _tabController.index = 1;
                                    setState(() {
                                      _type = value;
                                    });
                                  },
                                ),
                                child: Text(
                                  l10n.portScanRadioRange,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CustomTile(
                                leading: AdaptiveRadioButton<ScanType>(
                                  key: WidgetKey.singlePortScanRadioButton.key,
                                  value: ScanType.single,
                                  groupValue: _type,
                                  onChanged: (ScanType? value) {
                                    _tabController.index = 2;
                                    setState(() {
                                      _type = value;
                                    });
                                  },
                                ),
                                child: Text(l10n.portScanRadioSingle),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: ElevatedButton(
                                key: WidgetKey.portScanButton.key,
                                onPressed: _completed
                                    ? () {
                                        if (_formKey.currentState!.validate()) {
                                          _startScanning();
                                        }
                                      }
                                    : null,
                                child: Text(
                                  _completed
                                      ? l10n.portScanRun
                                      : l10n.portScanRunning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Container(
                      padding: const EdgeInsets.all(5.0),
                      child: DefaultTabController(
                        length: _tabCount,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tabs = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                TabBar(
                                  controller: _tabController,
                                  tabs: _tabs(l10n),
                                  labelColor:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                Flexible(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      Wrap(
                                        children: [
                                          _getDomainChip(
                                            WidgetKey.localIpChip.key,
                                            '192.168.1.1',
                                          ),
                                          _getDomainChip(
                                            WidgetKey.googleChip.key,
                                            'google.com',
                                          ),
                                          _getDomainChip(
                                            WidgetKey.youtubeChip.key,
                                            'youtube.com',
                                          ),
                                          _getDomainChip(
                                            WidgetKey.appleChip.key,
                                            'apple.com',
                                          ),
                                          _getDomainChip(
                                            WidgetKey.amazonChip.key,
                                            'amazon.com',
                                          ),
                                          _getDomainChip(
                                            WidgetKey.cloudflareChip.key,
                                            'cloudflare.com',
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        children: [
                                          _getCustomRangeChip(
                                            WidgetKey.knownPortChip.key,
                                            l10n.portScanRangeKnown,
                                            '0',
                                            '1024',
                                          ),
                                          _getCustomRangeChip(
                                            WidgetKey.shortPortChip.key,
                                            l10n.portScanRangeShort,
                                            '0',
                                            '100',
                                          ),
                                          _getCustomRangeChip(
                                            WidgetKey.veryShortPortChip.key,
                                            l10n.portScanRangeVeryShort,
                                            '0',
                                            '10',
                                          ),
                                          _getCustomRangeChip(
                                            WidgetKey.fullPortChip.key,
                                            l10n.portScanRangeFull,
                                            '0',
                                            '65535',
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        children: [
                                          _getSinglePortChip(
                                            l10n.portScanChipFtpData,
                                            '20',
                                          ),
                                          _getSinglePortChip(
                                            l10n.portScanChipFtpControl,
                                            '21',
                                          ),
                                          _getSinglePortChip(
                                            l10n.portScanChipSsh,
                                            '22',
                                          ),
                                          _getSinglePortChip(
                                            l10n.portScanChipHttp,
                                            '80',
                                          ),
                                          _getSinglePortChip(
                                            l10n.portScanChipHttps,
                                            '443',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                            if (constraints.maxHeight >= kTextTabBarHeight) {
                              return tabs;
                            }
                            return FittedBox(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: kTextTabBarHeight + 48,
                                child: tabs,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _openPorts.isEmpty
                      ? Center(
                          child: Text(
                            l10n.portScanEmptyResults,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _openPorts.length + kStoreBannerRows,
                          itemBuilder: (context, index) {
                            if (index < kStoreBannerRows) {
                              return const InlineAdaptiveBanner(
                                slot: StoreAdSlot.portScan,
                              );
                            }

                            final OpenPort openPort =
                                _openPorts.toList()[index - kStoreBannerRows];
                            final port = allPorts[openPort.port.toString()];

                            return Column(
                              children: [
                                AdaptiveListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(
                                    left: 10.0,
                                    right: 10.0,
                                  ),
                                  leading: Text(
                                    '${index - kStoreBannerRows + 1}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  trailing: Text(
                                    '${openPort.port}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                  ),
                                  title: port == null
                                      ? const SizedBox()
                                      : Text(
                                          l10n.portScanFinding(port.desc),
                                        ),
                                  subtitle: port == null
                                      ? const SizedBox()
                                      : Row(
                                          children: [
                                            if (port.isTCP)
                                              const Text('TCP   ')
                                            else
                                              const SizedBox(),
                                            if (port.isUDP)
                                              const Text('UDP   ')
                                            else
                                              const SizedBox(),
                                            Text(
                                              port.status,
                                            ),
                                          ],
                                        ),
                                ),
                                const Divider(height: 4),
                              ],
                            );
                          },
                        ),
                ),
                if (_completed && _openPorts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _foundLabel(l10n, _openPorts.length),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                l10n.portScanListLoadError,
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return Center(
              child: Text(l10n.portScanLoading),
            );
          }
        },
      )),
    );
  }
}

/// "found 1 reachable services" reads wrong in every language, so the singular
/// case has its own string instead of an interpolated plural.
String _foundLabel(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.portScanFoundOne : l10n.portScanFoundMany('$count');
