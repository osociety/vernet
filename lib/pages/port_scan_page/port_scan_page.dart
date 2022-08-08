import 'package:flutter/material.dart';

class PortScanPage extends StatefulWidget {
  final String target;
  const PortScanPage({Key? key, this.target = ''}) : super(key: key);

  @override
  State<PortScanPage> createState() => _PortScanPageState();
}

class _PortScanPageState extends State<PortScanPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Port Scanner'),
      ),
      body: Center(
        child: Text('Hi'),
      ),
    );
  }
}
