import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scna_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/widgets/host_scan_widget.dart';

class HostScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
        // actions: [
        //   if (_isScanning)
        //     Container(
        //       margin: const EdgeInsets.only(right: 20.0),
        //       child: CircularPercentIndicator(
        //         radius: 10.0,
        //         lineWidth: 2.5,
        //         percent: _progress / 100,
        //         backgroundColor: Colors.grey,
        //         progressColor: Colors.white,
        //       ),
        //     )
        //   else
        //     IconButton(
        //       onPressed: _getDevices,
        //       icon: const Icon(Icons.refresh),
        //     ),
        // ],
      ),
      body: BlocProvider(
        create: (context) =>
            getIt<HostScanBloc>()..add(const HostScanEvent.initialized()),
        child: HostScanWidget(),
      ),
    );
  }
}
