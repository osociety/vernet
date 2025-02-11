import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/port.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/custom_tile.dart';
import 'package:vernet/ui/popular_chip.dart';
import 'package:vernet/values/keys.dart';

class PortScanPage extends StatefulWidget {
  const PortScanPage({this.target = '', this.runDefaultScan = false});

  final String target;
  final bool runDefaultScan;

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
  final List<Tab> _tabs = [
    const Tab(text: 'Popular Targets'),
    const Tab(text: 'Custom Ranges'),
    const Tab(text: 'Popular Ports'),
  ];
  final _formKey = GlobalKey<FormState>();

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleEvent(ActiveHost? host) {
    debugPrint('Found open port : ${host!.openPorts}');
    setState(() {
      _openPorts.addAll(host.openPorts);
    });
  }

  void _handleOnDone() {
    setState(() {
      _completed = true;
    });
    if (_completed && _openPorts.isEmpty) _showSnackBar('No open ports found');
    debugPrint(
      _completed && _openPorts.isEmpty
          ? 'No open ports found'
          : 'Port Scan ended',
    );
  }

  StreamSubscription<ActiveHost>? _streamSubscription;
  bool _completed = true;
  void _startScanning() {
    setState(() {
      _completed = false;
      _openPorts.clear();
    });
    if (_type == ScanType.single) {
      PortScannerService.instance
          .isOpen(
        _targetIPEditingController.text,
        int.parse(_singlePortEditingController.text),
      )
          .then((value) {
        _handleEvent(value);
        _handleOnDone();
      });
    } else if (_type == ScanType.top) {
      _streamSubscription = PortScannerService.instance
          .customDiscover(
            _targetIPEditingController.text,
            timeout: Duration(milliseconds: appSettings.socketTimeout),
            async: true,
          )
          .listen(_handleEvent, onDone: _handleOnDone);
    } else {
      _streamSubscription = PortScannerService.instance
          .scanPortsForSingleDevice(
            _targetIPEditingController.text,
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
    _tabController = TabController(length: _tabs.length, vsync: this);
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
        decoration: const InputDecoration(filled: true, hintText: 'Enter Port'),
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
              decoration:
                  const InputDecoration(filled: true, hintText: 'Start Port'),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              validator: validatePorts,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _endPortEditingController,
              decoration:
                  const InputDecoration(filled: true, hintText: 'End Port'),
            ),
          ),
        ],
      );
    }
    return const Text('');
  }

  String? validatePorts(String? value) {
    if (value != null) {
      if (value.isEmpty) return 'Required';
      try {
        final int port = int.parse(value.trim());
        if (port < 0 || port > 65535) return 'Invalid port';
      } catch (e) {
        return 'Not a number';
      }
    }
    return null;
  }

  String? validateIP(String? value) {
    if (value != null) {
      if (value.isEmpty) return 'Required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Ports Scanner'),
      ),
      body: FutureBuilder<Map<String, Port>>(
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
                                  decoration: const InputDecoration(
                                    filled: true,
                                    hintText: 'Enter a domain or IP',
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
                                leading: Radio<ScanType>(
                                  value: ScanType.top,
                                  groupValue: _type,
                                  onChanged: (ScanType? value) {
                                    _tabController.index = 0;
                                    setState(() {
                                      _type = value;
                                    });
                                  },
                                ),
                                child: const Text('Top'),
                              ),
                            ),
                            Expanded(
                              child: CustomTile(
                                leading: Radio<ScanType>(
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
                                child: const Text(
                                  'Range',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CustomTile(
                                leading: Radio<ScanType>(
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
                                child: const Text('Single'),
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
                                child: Text(_completed ? 'Scan' : 'Scanning'),
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
                        length: _tabs.length,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TabBar(
                              controller: _tabController,
                              tabs: _tabs,
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
                                        '0-1024 (known)',
                                        '0',
                                        '1024',
                                      ),
                                      _getCustomRangeChip(
                                        WidgetKey.shortPortChip.key,
                                        '0-100 (short)',
                                        '0',
                                        '100',
                                      ),
                                      _getCustomRangeChip(
                                        WidgetKey.veryShortPortChip.key,
                                        '0-10 (very short)',
                                        '0',
                                        '10',
                                      ),
                                      _getCustomRangeChip(
                                        WidgetKey.fullPortChip.key,
                                        '0-65535 (Full)',
                                        '0',
                                        '65535',
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    children: [
                                      _getSinglePortChip('20 (FTP Data)', '20'),
                                      _getSinglePortChip(
                                        '21 (FTP Control)',
                                        '21',
                                      ),
                                      _getSinglePortChip('22 (SSH)', '22'),
                                      _getSinglePortChip('80 (HTTP)', '80'),
                                      _getSinglePortChip('443 (HTTPS)', '443'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _openPorts.isEmpty
                      ? const Center(
                          child: Text(
                            'No open ports found yet.\nOpen ports will appear here.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _openPorts.length,
                          itemBuilder: (context, index) {
                            final OpenPort openPort =
                                _openPorts.toList()[index];
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
                                    '${index + 1}',
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
                                          port.desc,
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
              ],
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text(
                'There is an error while loading..\nPlease try again after sometime.',
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return const Center(
              child: Text('Loading...'),
            );
          }
        },
      ),
    );
  }
}
