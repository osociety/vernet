import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:latlong2/latlong.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:vernet/pages/isp_page/bloc/isp_page_bloc.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

class IspPageWidget extends StatelessWidget {
  const IspPageWidget({super.key, required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IspPageBloc, IspPageState>(
      builder: (context, state) {
        return state.map(
          initial: (_) => Container(),
          loadInProgress: (event) => IspPageContent(
            client: client,
            childrens: const [AdaptiveCircularProgressIndicator()],
          ),
          loadFailure: (event) => const Center(
            child: Text('We could not load internet service details'),
          ),
          loadSuccess: (success) {
            if (success.bestServers.isEmpty) {
              return IspPageContent(
                client: client,
                childrens: const [
                  Expanded(
                    child: Center(
                      child: Text('No nearby test servers were found.'),
                    ),
                  ),
                ],
              );
            }

            final serverPoints = success.bestServers
                .map((server) => LatLng(server.latitude, server.longitude))
                .toSet()
                .toList();

            return IspPageContent(
              client: client,
              childrens: [
                Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: serverPoints.first,
                          initialZoom: 10.5,
                          initialCameraFit: serverPoints.length > 1
                              ? CameraFit.coordinates(
                                  coordinates: serverPoints,
                                  padding: const EdgeInsets.all(36),
                                  maxZoom: 10.5,
                                )
                              : null,
                        ),
                        children: [
                          TileLayer(
                            minZoom: 1,
                            maxZoom: 18,
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'org.fsociety.vernet',
                          ),
                          MarkerLayer(
                            markers: success.bestServers
                                .asMap()
                                .entries
                                .map((entry) {
                              final server = entry.value;
                              final isClosest = entry.key == 0;
                              return Marker(
                                point: LatLng(
                                  server.latitude,
                                  server.longitude,
                                ),
                                width: 36,
                                height: 36,
                                child: Tooltip(
                                  message: '${server.name}, ${server.country}',
                                  child: Icon(
                                    Icons.pin_drop,
                                    size: 32,
                                    color: isClosest
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                '© OpenStreetMap contributors',
                                style: TextStyle(fontSize: 9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Closest test server: ${success.bestServers.first.name}, ${success.bestServers.first.country}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const Text('Available test servers'),
                Expanded(
                  child: ListView.builder(
                    itemBuilder: (context, item) {
                      final server = success.bestServers[item];
                      return AdaptiveListTile(
                        leading: Text('${item + 1}'),
                        title: Text('${server.name}, ${server.country}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Response time: ${server.latency} ms'),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [Text('Provided by ${server.sponsor}')],
                            )
                          ],
                        ),
                      );
                    },
                    itemCount: success.bestServers.length,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class IspPageContent extends StatelessWidget {
  const IspPageContent(
      {super.key, required this.childrens, required this.client});
  final List<Widget> childrens;
  final Client client;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdaptiveListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(client.isp),
              RatingBar.builder(
                initialRating: client.ispRating,
                minRating: 1.0,
                itemSize: 25,
                glowColor: Colors.blue,
                allowHalfRating: true,
                ignoreGestures: true,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {},
              ),
            ],
          ),
          subtitle: Text('Your provider rating: ${client.ispRating} out of 5'),
        ),
        ...childrens,
      ],
    );
  }
}
