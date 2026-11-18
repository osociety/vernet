import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vernet/models/subnet_calculation.dart';
import 'package:vernet/services/subnet_calculator_service.dart';
import 'package:vernet/utils/localization.dart';

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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.subnetCalcTitle)),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.l10n.subnetCalcSubtitle),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _calculate(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.subnetCalcFieldLabel,
              hintText: l10n.subnetCalcFieldHint,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: Text(l10n.subnetCalcRun),
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
      )),
    );
  }

  Widget _resultCard(BuildContext context, SubnetCalculation result) {
    final l10n = context.l10n;
    // The tooltip names the row in the objective case, which German spells
    // differently from the label, so each row carries its own copy text.
    final rows = <(String, String, String)>[
      (
        l10n.subnetCalcIpVersion,
        l10n.subnetCalcCopyIpVersion,
        result.ipVersion
      ),
      (
        l10n.subnetCalcNetworkAddress,
        l10n.subnetCalcCopyNetworkAddress,
        result.networkAddress,
      ),
      (
        l10n.subnetCalcSubnetMask,
        l10n.subnetCalcCopySubnetMask,
        result.subnetMask
      ),
      if (result.broadcastAddress != null)
        (
          l10n.subnetCalcBroadcastAddress,
          l10n.subnetCalcCopyBroadcastAddress,
          result.broadcastAddress!,
        ),
      (
        l10n.subnetCalcFirstAddress,
        l10n.subnetCalcCopyFirstAddress,
        result.firstAddress,
      ),
      (
        l10n.subnetCalcLastAddress,
        l10n.subnetCalcCopyLastAddress,
        result.lastAddress
      ),
      (
        l10n.subnetCalcAddressCount,
        l10n.subnetCalcCopyAddressCount,
        result.addressCount,
      ),
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
                subtitle: SelectableText(row.$3),
                trailing: IconButton(
                  tooltip: row.$2,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: row.$3));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.subnetCalcCopied(row.$1))),
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
