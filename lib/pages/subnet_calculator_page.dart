import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/models/subnet_calculation.dart';
import 'package:vernet/services/subnet_calculator_service.dart';

class SubnetCalculatorPage extends StatefulWidget {
  const SubnetCalculatorPage({super.key});

  @override
  State<SubnetCalculatorPage> createState() => _SubnetCalculatorPageState();
}

class _SubnetCalculatorPageState extends State<SubnetCalculatorPage> {
  final _controller = TextEditingController();
  final _service = const SubnetCalculatorService();
  SubnetCalculation? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _calculate() {
    try {
      final result = _service.calculate(_controller.text);
      setState(() {
        _result = result;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _result = null;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IP subnet calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Calculate IPv4 or IPv6 subnet details from an address and prefix.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _calculate(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'IP address / prefix',
              hintText: '192.168.1.10/24 or 2001:db8::1/64',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 16),
            _resultCard(context, result),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, SubnetCalculation result) {
    final rows = <(String, String)>[
      ('IP version', result.ipVersion),
      ('Network address', result.networkAddress),
      ('Subnet mask', result.subnetMask),
      if (result.broadcastAddress != null)
        ('Broadcast address', result.broadcastAddress!),
      ('First address', result.firstAddress),
      ('Last address', result.lastAddress),
      ('Addresses in subnet', result.addressCount),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.networkAddress}/${result.cidr}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(row.$1),
                subtitle: SelectableText(row.$2),
                trailing: IconButton(
                  tooltip: 'Copy ${row.$1.toLowerCase()}',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: row.$2));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${row.$1} copied')),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
