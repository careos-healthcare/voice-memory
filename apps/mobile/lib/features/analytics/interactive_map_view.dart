import 'package:archiveme_mobile/features/analytics/contribution_calendar.dart';
import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap pins for moments that stored coordinates.
class InteractiveMapView extends StatelessWidget {
  const InteractiveMapView({
    required this.clusters,
    required this.onClusterTap,
    this.selectedClusterId,
    this.showTiles = true,
    super.key,
  });

  final List<MapCluster> clusters;
  final ValueChanged<MapCluster> onClusterTap;
  final String? selectedClusterId;
  final bool showTiles;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) {
      return const SizedBox(
        key: Key('timeline_map_empty'),
        height: 220,
        child: Center(child: Text('No places saved on these moments.')),
      );
    }
    final points = [
      for (final cluster in clusters)
        LatLng(cluster.latitude, cluster.longitude),
    ];
    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: points.length == 1
            ? MapOptions(initialCenter: points.first, initialZoom: 12)
            : MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(32),
                ),
              ),
        children: [
          if (showTiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.voicememory.mobile',
            ),
          MarkerLayer(
            markers: [
              for (final cluster in clusters)
                Marker(
                  point: LatLng(cluster.latitude, cluster.longitude),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    key: Key('timeline_map_cluster_${cluster.id}'),
                    onTap: () => onClusterTap(cluster),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dayCellColor(
                          count: cluster.entryIds.length,
                          sentiment: cluster.meanSentiment,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cluster.id == selectedClusterId
                              ? AppTokens.neutral900
                              : AppTokens.neutral50,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${cluster.entryIds.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
