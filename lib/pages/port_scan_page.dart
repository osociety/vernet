import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_tools/network_tools.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/port.dart';
import 'package:vernet/ui/custom_tile.dart';
import 'package:vernet/ui/popular_chip.dart';

class PortScanPage extends StatefulWidget {
  final String target;
  const PortScanPage({Key? key, this.target = ''}) : super(key: key);

  @override
  _PortScanPageState createState() => _PortScanPageState();
}

enum ScanType { single, top, range }

class _PortScanPageState extends State<PortScanPage>
    with SingleTickerProviderStateMixin {
  Set<OpenPort> _openPorts = {};
  Map<String, Port> _allPorts = {};
  double _progress = 0;
  TextEditingController _targetIPEditingController = TextEditingController();
  TextEditingController _singlePortEditingController = TextEditingController();
  TextEditingController _startPortEditingController = TextEditingController();
  TextEditingController _endPortEditingController = TextEditingController();
  late TabController _tabController;
  List<Tab> _tabs = [
    Tab(text: "Popular Targets"),
    Tab(text: "Custom Ranges"),
    Tab(text: "Popular Ports")
  ];
  final _formKey = GlobalKey<FormState>();

  _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleProgress(double progress) {
    debugPrint('Progress : $progress');
    if (this.mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  void _handleEvent(OpenPort port) {
    if (port.isOpen) {
      setState(() {
        _openPorts.add(port);
      });
    }
  }

  void _handleOnDone() {
    setState(() {
      _completed = true;
    });
    if (_completed && _openPorts.isEmpty) _showSnackBar('No open ports found');
  }

  StreamSubscription<OpenPort>? _streamSubscription;
  bool _completed = true;
  _startScanning() {
    setState(() {
      _completed = false;
      _openPorts.clear();
    });
    if (_type == ScanType.single) {
      PortScanner.isOpen(_targetIPEditingController.text,
              int.parse(_singlePortEditingController.text))
          .then((value) {
        _handleEvent(value);
        _handleOnDone();
      });
    } else if (_type == ScanType.top) {
      _streamSubscription = PortScanner.customDiscover(
        _targetIPEditingController.text,
        timeout: Duration(milliseconds: appSettings.socketTimeout),
        progressCallback: _handleProgress,
      ).listen(_handleEvent, onDone: _handleOnDone);
    } else {
      _streamSubscription = PortScanner.discover(
        _targetIPEditingController.text,
        startPort: int.parse(_startPortEditingController.text),
        endPort: int.parse(_endPortEditingController.text),
        timeout: Duration(milliseconds: appSettings.socketTimeout),
        progressCallback: _handleProgress,
      ).listen(_handleEvent, onDone: _handleOnDone);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _targetIPEditingController.text = widget.target;
    PortDescLoader("assets/ports_lists.json").load().then((value) {
      debugPrint("Fetched ports : ${value.length}");
      setState(() {
        _allPorts.addAll(value);
      });
    });
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

  _getCustomRangeChip(String label, String start, String end) {
    return PopularChip(
      label: label,
      onPressed: () {
        _startPortEditingController.text = start;
        _endPortEditingController.text = end;
      },
    );
  }

  _getSinglePortChip(String label, String port) {
    return PopularChip(
      label: label,
      onPressed: () {
        _singlePortEditingController.text = port;
      },
    );
  }

  _getDomainChip(String label) {
    return PopularChip(
      label: label,
      onPressed: () {
        _targetIPEditingController.text = label;
      },
    );
  }

  _getFields() {
    if (_type == ScanType.single) {
      return TextFormField(
        keyboardType: TextInputType.number,
        validator: validatePorts,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: _singlePortEditingController,
        decoration: InputDecoration(filled: true, hintText: 'Enter Port'),
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
              decoration: InputDecoration(filled: true, hintText: 'Start Port'),
            ),
          ),
          SizedBox(width: 3),
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              validator: validatePorts,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _endPortEditingController,
              decoration: InputDecoration(filled: true, hintText: 'End Port'),
            ),
          )
        ],
      );
    }
  }

  String? validatePorts(String? value) {
    if (value != null) {
      if (value.isEmpty) return 'Required';
      try {
        int port = int.parse(value.trim());
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

  //TODO: add progress bar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Open Ports Scanner'),
        actions: [
          _completed
              ? SizedBox()
              : Container(
                  margin: EdgeInsets.only(right: 20.0),
                  child: new CircularPercentIndicator(
                    radius: 20.0,
                    lineWidth: 2.5,
                    percent: _progress / 100,
                    backgroundColor: Colors.grey,
                    progressColor: Colors.white,
                  ),
                ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
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
                          hintText: 'Enter a domain or IP',
                        ),
                      )),
                      SizedBox(width: 3),
                      _type != ScanType.top
                          ? Expanded(child: _getFields())
                          : SizedBox(),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CustomTile(
                        child: const Text('Top'),
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
                      ),
                    ),
                    Expanded(
                      child: CustomTile(
                        child: const Text('Range'),
                        leading: Radio<ScanType>(
                          value: ScanType.range,
                          groupValue: _type,
                          onChanged: (ScanType? value) {
                            _tabController.index = 1;
                            setState(() {
                              _type = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: CustomTile(
                        child: const Text('Single'),
                        leading: Radio<ScanType>(
                          value: ScanType.single,
                          groupValue: _type,
                          onChanged: (ScanType? value) {
                            _tabController.index = 2;
                            setState(() {
                              _type = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(3.0),
                      child: ElevatedButton(
                        onPressed: _completed
                            ? () {
                                if (_formKey.currentState!.validate())
                                  _startScanning();
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
          Expanded(
            flex: 1,
            child: Card(
              child: DefaultTabController(
                length: _tabs.length,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      child: TabBar(
                          controller: _tabController,
                          tabs: _tabs,
                          labelColor: Theme.of(context).accentColor),
                    ),
                    Flexible(
                      child: Container(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            Container(
                              child: Wrap(
                                children: [
                                  _getDomainChip('192.168.1.1'),
                                  _getDomainChip('google.com'),
                                  _getDomainChip('youtube.com'),
                                  _getDomainChip('apple.com'),
                                  _getDomainChip('microsoft.com'),
                                  _getDomainChip('cloudflare.com')
                                ],
                              ),
                            ),
                            Container(
                              child: Wrap(
                                children: [
                                  _getCustomRangeChip(
                                      '0-1024 (known)', '0', '1024'),
                                  _getCustomRangeChip(
                                      '0-100 (short)', '0', '100'),
                                  _getCustomRangeChip(
                                      '0-10 (very short)', '0', '10'),
                                  _getCustomRangeChip(
                                      '0-65535 (Full)', '0', '65535'),
                                ],
                              ),
                            ),
                            Container(
                              child: Wrap(
                                children: [
                                  _getSinglePortChip('20 (FTP Data)', '20'),
                                  _getSinglePortChip('21 (FTP Control)', '21'),
                                  _getSinglePortChip('22 (SSH)', '22'),
                                  _getSinglePortChip('80 (HTTP)', '80'),
                                  _getSinglePortChip('443 (HTTPS)', '443'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _openPorts.isEmpty
                ? Center(
                    child: Text(
                      'No open ports found yet.\nOpen ports will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _openPorts.length,
                    itemBuilder: (context, index) {
                      OpenPort _openPort = _openPorts.toList()[index];
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding:
                                EdgeInsets.only(left: 10.0, right: 10.0),
                            leading: Text(
                              '${_openPort.port}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headline6!
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                            ),
                            title: _allPorts.isEmpty
                                ? SizedBox()
                                : Text(
                                    _allPorts[_openPort.port.toString()]!.desc),
                            subtitle: _allPorts.isEmpty
                                ? SizedBox()
                                : Row(
                                    children: [
                                      _allPorts[_openPort.port.toString()]!
                                              .isTCP
                                          ? Text('TCP   ')
                                          : SizedBox(),
                                      _allPorts[_openPort.port.toString()]!
                                              .isUDP
                                          ? Text('UDP   ')
                                          : SizedBox(),
                                      Text(_allPorts[_openPort.port.toString()]!
                                          .status),
                                    ],
                                  ),
                          ),
                          Divider(height: 4),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
