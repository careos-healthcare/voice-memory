import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../storage/encrypted_json_file_store.dart';
import 'spatial_nexus_models.dart';
import 'spatial_nexus_renderer.dart';
import 'spatial_sound_engine.dart';

final class SpatialNexusPreferences {
  const SpatialNexusPreferences({
    this.preset = SpatialEnvironmentPreset.neuralVoid,
    this.spatialAudioEnabled = false,
  });

  final SpatialEnvironmentPreset preset;
  final bool spatialAudioEnabled;

  Map<String, Object> toJson() => {
    'version': 1,
    'preset': preset.name,
    'spatialAudioEnabled': spatialAudioEnabled,
  };

  factory SpatialNexusPreferences.fromJson(Map<String, dynamic> json) =>
      SpatialNexusPreferences(
        preset: SpatialEnvironmentPreset.values.firstWhere(
          (preset) => preset.name == json['preset'],
          orElse: () => SpatialEnvironmentPreset.neuralVoid,
        ),
        spatialAudioEnabled: json['spatialAudioEnabled'] == true,
      );
}

final class SpatialNexusService {
  SpatialNexusService({
    required this.renderer,
    required this.sound,
    required this.store,
  });

  final SpatialNexusRenderer renderer;
  final SpatialSoundEngine sound;
  final EncryptedJsonFileStore store;
  SpatialNexusPreferences _preferences = const SpatialNexusPreferences();

  SpatialNexusPreferences get preferences => _preferences;

  Future<void> initialize() async {
    final raw = await store.readJson();
    if (raw is Map) {
      _preferences = SpatialNexusPreferences.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
  }

  Future<void> updatePreferences(SpatialNexusPreferences preferences) async {
    _preferences = preferences;
    await store.writeJson(preferences.toJson());
    await sound.setPaused(!preferences.spatialAudioEnabled);
  }

  Future<File> exportPortableSnapshot(
    SpatialScene scene,
    File destination,
  ) async {
    if (scene.nodes.length > 1024 || scene.edges.length > 4096) {
      throw StateError('Spatial snapshot exceeds portable bounds.');
    }
    final aliases = <String, String>{};
    for (final node in scene.nodes) {
      aliases[node.id] = sha256
          .convert(utf8.encode('spatial-nexus-v1:${node.id}'))
          .toString()
          .substring(0, 20);
    }
    final payload = {
      'schema': 'archive-spatial-nexus',
      'version': 1,
      'preset': scene.preset.name,
      'nodes': [
        for (var index = 0; index < scene.nodes.length; index++)
          {
            'id': aliases[scene.nodes[index].id],
            'label': '${scene.nodes[index].type} ${index + 1}',
            'type': scene.nodes[index].type,
            'position': scene.nodes[index].position.toJson(),
            'radius': scene.nodes[index].radius,
            'valence': scene.nodes[index].valence,
            'horizon': scene.nodes[index].isHorizonProjection,
          },
      ],
      'edges': [
        for (final edge in scene.edges)
          if (aliases[edge.sourceId] != null && aliases[edge.targetId] != null)
            {
              'source': aliases[edge.sourceId],
              'target': aliases[edge.targetId],
              'weight': edge.weight,
            },
      ],
    };
    await destination.parent.create(recursive: true);
    await destination.writeAsString(jsonEncode(payload), flush: true);
    return destination;
  }

  Future<void> clear() async {
    _preferences = const SpatialNexusPreferences();
    await sound.setPaused(true);
    await store.writeJson(_preferences.toJson());
  }

  Future<void> dispose() => sound.dispose();
}
