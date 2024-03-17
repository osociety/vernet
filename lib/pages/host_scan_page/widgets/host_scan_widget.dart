import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/host_scan_page/device_in_the_network.dart';
import 'package:vernet/pages/host_scan_page/host_scna_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';

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
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          foundNewDevice: (FoundNewDevice value) {
            final List<DeviceInTheNetwork> activeHostList =
                value.activeHostList;

            return Flex(
              direction: Axis.vertical,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text("Found ${activeHostList.length} devices"),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: activeHostList.length,
                    itemBuilder: (context, index) {
                      final DeviceInTheNetwork host = activeHostList[index];
                      return ListTile(
                        leading: Icon(host.iconData),
                        title: FutureBuilder(
                          future: host.make,
                          builder: (context, AsyncSnapshot<String?> snapshot) {
                            return Text(snapshot.data ?? '');
                          },
                          initialData: 'Generic Device',
                        ),
                        subtitle: Text(
                          '${host.internetAddress.address} ${host.mac}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Scan open ports for this target',
                          icon: const Icon(Icons.radar),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PortScanPage(
                                  target: host.internetAddress.address,
                                  runDefaultScan: true,
                                ),
                              ),
                            );
                          },
                        ),
                        onLongPress: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: host.internetAddress.address,
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
          },
          loadFailure: (value) {
            return const Text('Failure');
          },
          loadSuccess: (value) {
            return const Text('Done');
          },
          error: (Error value) {
            return const Text('Error');
          },
        );
      },
    );
  }
}
