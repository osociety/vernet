import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

class HostScanWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HostScanBloc, HostScanState>(
      builder: (context, state) {
        return state.map(
          initial: (_) => Container(),
          loadInProgress: (value) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(
                      height: 30,
                    ),
                    Text(
                      appSettings.gatewayIP.isNotEmpty
                          ? 'Searching for devices in ${appSettings.gatewayIP} network'
                          : 'Searching for devices in your local network',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
          foundNewDevice: (FoundNewDevice value) {
            return _devicesWidget(context, value.activeHosts.toList(), true);
          },
          loadFailure: (value) {
            return const Text('Failure');
          },
          loadSuccess: (value) {
            return _devicesWidget(context, value.activeHosts.toList(), false);
          },
          error: (Error value) {
            return const Text('Error');
          },
        );
      },
    );
  }

  Widget _devicesWidget(
    BuildContext context,
    List<Device> activeHostList,
    bool loading,
  ) {
    return Flex(
      direction: Axis.vertical,
      children: [
        AdaptiveListTile(
          title: Text(
            "Found ${activeHostList.length} devices",
            textAlign: TextAlign.center,
          ),
          trailing: loading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 25.0,
                    width: 25.0,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                )
              : IconButton(
                  onPressed: () {
                    context
                        .read<HostScanBloc>()
                        .add(const HostScanEvent.initialized());
                  },
                  icon: const Icon(Icons.replay),
                ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: activeHostList.length,
            itemBuilder: (context, index) {
              final Device host = activeHostList[index];
              return AdaptiveListTile(
                // leading: Icon(host.iconData), todo: geticondata
                title: Text(host.make),
                subtitle: Text(
                  '${host.internetAddress} (${host.macAddress ?? ''})',
                ),
                trailing: IconButton(
                  tooltip: 'Scan open ports for this target',
                  icon: const Icon(Icons.radar),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PortScanPage(
                          target: host.internetAddress,
                        ),
                      ),
                    );
                  },
                ),
                onLongPress: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: host.internetAddress,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('IP copied to clipboard'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
