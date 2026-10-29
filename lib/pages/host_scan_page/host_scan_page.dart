import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/pages/host_scan_page/widgets/host_scan_widget.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class HostScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.hostScanPageTitle),
        actions: [
          IconButton(
            key: WidgetKey.scanHistoryIconButton.key,
            tooltip: StringValue.previousScansTitle,
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const ScanHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocProvider(
        create: (context) =>
            getIt<HostScanBloc>()..add(const HostScanEvent.initialized()),
        child: HostScanWidget(),
      ),
    );
  }
}
