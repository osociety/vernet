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
            child: Text('Error'),
          ),
          loadSuccess: (success) => IspPageContent(
            client: client,
            childrens: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          success.bestServers.first.latitude,
                          success.bestServers.first.longitude,
                        ),
                      ),
                      children: [
                        TileLayer(
                          minZoom: 1,
                          maxZoom: 18,
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'org.fsociety.vernet',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(
                              success.bestServers.first.latitude,
                              success.bestServers.first.longitude,
                            ),
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.pin_drop,
                              size: 40,
                            ),
                          )
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Text(
                        'Best Server: ${success.bestServers.first.name}, ${success.bestServers.first.country}'),
                  ),
                ],
              ),
              const Text("List of Servers"),
              Expanded(
                child: ListView.builder(
                  itemBuilder: (context, item) => AdaptiveListTile(
                    title: Text(
                        '${success.bestServers[item].name}, ${success.bestServers[item].country}'),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Latency: ${success.bestServers[item].latency} ms'),
                        Text(
                            'Sponsored by ${success.bestServers[item].sponsor}')
                      ],
                    ),
                  ),
                  itemCount: success.bestServers.length,
                ),
              ),
            ],
          ),
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
          subtitle: Text('Your ISP is rated ${client.ispRating} out of 5'),
        ),
        ...childrens,
      ],
    );
  }
}
