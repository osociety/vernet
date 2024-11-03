import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/widgets/host_scan_widget.dart';
import 'package:vernet/values/strings.dart';

class HostScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.hostScanPageTitle),
      ),
      body: BlocProvider(
        create: (context) =>
            getIt<HostScanBloc>()..add(const HostScanEvent.initialized()),
        child: HostScanWidget(),
      ),
    );
  }
}
