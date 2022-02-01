import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/pages/host_scan_page/host_scna_bloc/host_scan_bloc.dart';

class ConfigureNewCbjCompWidgets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HostScanBloc, HostScanState>(
      builder: (context, state) {
        //   return state.map(
        //       initial: (_) {
        //     context.read<ConfigureNewCbjCompBloc>().add(
        //       ConfigureNewCbjCompEvent.sendHotSpotInformation(
        //         cbjCompEntityInBuild,
        //       ),
        //     );
        // );
        return const SizedBox();
      },
    );
  }
}
