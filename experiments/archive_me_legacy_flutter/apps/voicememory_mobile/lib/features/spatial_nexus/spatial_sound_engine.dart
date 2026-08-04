import 'dart:async';
import 'dart:math' as math;

import 'spatial_nexus_models.dart';

final class SpatialAudioParameters {
  const SpatialAudioParameters({
    required this.gain,
    required this.pan,
    required this.azimuthRadians,
    required this.elevationRadians,
    required this.distance,
  });

  final double gain;
  final double pan;
  final double azimuthRadians;
  final double elevationRadians;
  final double distance;
}

abstract interface class SpatialAudioDriver {
  Future<void> updateSource(String sourceId, SpatialAudioParameters parameters);
  Future<void> stopSource(String sourceId);
  Future<void> stopAll();
  Future<void> dispose();
}

final class SilentSpatialAudioDriver implements SpatialAudioDriver {
  const SilentSpatialAudioDriver();

  @override
  Future<void> updateSource(
    String sourceId,
    SpatialAudioParameters parameters,
  ) async {}
  @override
  Future<void> stopSource(String sourceId) async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> dispose() async {}
}

final class SpatialSoundEngine {
  SpatialSoundEngine({
    SpatialAudioDriver? driver,
    this.audibleRadius = 5,
    this.maxActiveSources = 4,
  }) : driver = driver ?? const SilentSpatialAudioDriver();

  final SpatialAudioDriver driver;
  final double audibleRadius;
  final int maxActiveSources;
  final Set<String> _active = {};
  bool _paused = false;

  SpatialAudioParameters position({
    required SpatialVector3 listener,
    required SpatialVector3 source,
  }) {
    final delta = source - listener;
    final distance = delta.length;
    final horizontal = math.sqrt(delta.x * delta.x + delta.z * delta.z);
    final azimuth = math.atan2(delta.x, -delta.z);
    final elevation = math.atan2(delta.y, math.max(horizontal, 1e-9));
    final gain = distance >= audibleRadius
        ? 0.0
        : math.pow(1 - distance / audibleRadius, 2).toDouble();
    return SpatialAudioParameters(
      gain: gain,
      pan: math.sin(azimuth).clamp(-1, 1),
      azimuthRadians: azimuth,
      elevationRadians: elevation,
      distance: distance,
    );
  }

  Future<void> update({
    required SpatialVector3 listener,
    required Iterable<SpatialNode> sources,
  }) async {
    if (_paused) return;
    final ranked =
        sources
            .map(
              (node) => (
                node: node,
                parameters: position(listener: listener, source: node.position),
              ),
            )
            .where((item) => item.parameters.gain > 0)
            .toList()
          ..sort(
            (left, right) =>
                right.parameters.gain.compareTo(left.parameters.gain),
          );
    final next = ranked
        .take(maxActiveSources)
        .map((item) => item.node.id)
        .toSet();
    for (final sourceId in _active.difference(next)) {
      await driver.stopSource(sourceId);
    }
    for (final item in ranked.take(maxActiveSources)) {
      await driver.updateSource(item.node.id, item.parameters);
    }
    _active
      ..clear()
      ..addAll(next);
  }

  Future<void> setPaused(bool paused) async {
    _paused = paused;
    if (paused) {
      _active.clear();
      await driver.stopAll();
    }
  }

  Future<void> dispose() async {
    await driver.stopAll();
    await driver.dispose();
  }
}
