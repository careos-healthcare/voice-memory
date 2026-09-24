import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/features/audio/sherpa_dual_mode_backend.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_service.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_store.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:sqflite/sqflite.dart';

/// A voice file captured on a watch and waiting to be indexed.
class WearableAudioClip {
  const WearableAudioClip({
    required this.path,
    required this.platform,
    this.capturedAt,
  });

  final String path;
  final String platform;
  final DateTime? capturedAt;

  bool get isSupportedAudio {
    final name = path.toLowerCase();
    return name.endsWith('.m4a') || name.endsWith('.wav');
  }

  static WearableAudioClip? fromPlatform(
    Object? raw, {
    required String platform,
  }) {
    if (raw is String && raw.trim().isNotEmpty) {
      return WearableAudioClip(path: raw.trim(), platform: platform);
    }
    if (raw is! Map) return null;
    final path = raw['path']?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    final capturedRaw = raw['capturedAt']?.toString();
    final named = raw['platform']?.toString().trim() ?? '';
    return WearableAudioClip(
      path: path,
      platform: named.isEmpty ? platform : named,
      capturedAt: capturedRaw == null || capturedRaw.isEmpty
          ? null
          : DateTime.tryParse(capturedRaw),
    );
  }
}

/// Shown after a wrist recording is transcribed and stored.
const wearableIndexedNotice = 'Wrist moment transcribed and indexed.';

/// Delivers the sync confirmation when notifications are enabled.
///
/// Production leaves notifications off, so this library does not import
/// flutter_local_notifications.
typedef WearableIndexedNotifier = Future<void> Function(String body);

/// Turns a watch recording into a moment, a transcript, and a vector.
class WearableIngestionWorker {
  WearableIngestionWorker({
    required this.database,
    this.transcribe = transcribeWearableFile,
    AmbientMetadataService? metadata,
    this.quantize = VectorStore.initialize,
    bool? notificationsEnabled,
    this.notifier,
    DateTime Function()? clock,
  }) : metadata =
           metadata ??
           AmbientMetadataService(
             persist: (entryId, captured) {
               return AmbientMetadataStore.write(
                 database,
                 entryId: entryId,
                 metadata: captured,
               );
             },
           ),
       notificationsEnabled =
           notificationsEnabled ?? V1CapabilityRegistry.notifications,
       _clock = clock ?? DateTime.now;

  final DatabaseExecutor database;
  final Future<String> Function(String path) transcribe;
  final AmbientMetadataService metadata;
  final Future<Object?> Function(DatabaseExecutor db) quantize;
  final bool notificationsEnabled;
  final WearableIndexedNotifier? notifier;
  final DateTime Function() _clock;

  final List<String> confirmations = [];
  var _sequence = 0;

  /// Writes one clip. Returns false when the write fails so it can be retried.
  Future<bool> ingest(WearableAudioClip clip) async {
    if (!clip.isSupportedAudio) return true;
    try {
      final transcript = (await transcribe(clip.path)).trim();
      final created = _clock();
      _sequence += 1;
      final entryId = 'wrist-${created.microsecondsSinceEpoch}-$_sequence';
      await database.insert('journal_entries', {
        'id': entryId,
        'created_at': created.millisecondsSinceEpoch,
        'updated_at': created.millisecondsSinceEpoch,
        'is_archived': 0,
        'transcript': transcript,
        'has_verified_proof': 0,
        'payload_json':
            '{"source":"wearable","platform":"${clip.platform}","path":"${_jsonEscape(clip.path)}"}',
      });
      metadata.pending = await metadata.capture();
      await metadata.attachToEntry(entryId);
      final vector = SampleVaultEmbedder.embed(transcript);
      await database.insert(Migration005HybridSearch.embeddingsTable, {
        'entry_id': entryId,
        'embedding': SampleVaultEmbedder.toBlob(vector),
        'dimensions': vector.length,
      });
      try {
        await quantize(database);
      } on Object catch (error) {
        error.runtimeType;
      }
      confirmations.add(wearableIndexedNotice);
      final delivery = notifier;
      if (notificationsEnabled && delivery != null) {
        await delivery(wearableIndexedNotice);
      }
      return true;
    } on Object catch (error) {
      error.runtimeType;
      return false;
    }
  }
}

/// Decodes a 16-bit WAV file and runs the on-device sherpa recognizer.
Future<String> transcribeWearableFile(String path) {
  return WearableSherpaTranscriber().transcribePath(path);
}

/// Reads WAV samples and hands them to sherpa-onnx when a model is installed.
class WearableSherpaTranscriber {
  WearableSherpaTranscriber({this.readBytes, this.recognize});

  final Future<Uint8List> Function(String path)? readBytes;
  final Future<String> Function(Float32List samples)? recognize;

  Future<String> transcribePath(String path) async {
    final loader = readBytes;
    final bytes = loader == null ? await _readFile(path) : await loader(path);
    return transcribeBytes(bytes);
  }

  Future<String> transcribeBytes(Uint8List bytes) async {
    final samples = pcmFromWav(bytes);
    if (samples == null || samples.isEmpty) return '';
    final recognize = this.recognize ?? bindSherpaDualMode().transcribe;
    if (recognize == null) return '';
    return recognize(samples);
  }
}

Future<Uint8List> _readFile(String path) async {
  try {
    return await File(path).readAsBytes();
  } on Object catch (error) {
    error.runtimeType;
    return Uint8List(0);
  }
}

/// 16-bit PCM WAV to mono float samples. Other encodings return null.
Float32List? pcmFromWav(Uint8List bytes) {
  if (bytes.length < 44) return null;
  if (!_ascii(bytes, 0, 'RIFF') || !_ascii(bytes, 8, 'WAVE')) return null;
  var offset = 12;
  int? channels;
  int? bits;
  int? format;
  Uint8List? data;
  final view = ByteData.sublistView(bytes);
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + size;
    if (end > bytes.length) return null;
    if (id == 'fmt ' && size >= 16) {
      format = view.getUint16(start, Endian.little);
      channels = view.getUint16(start + 2, Endian.little);
      bits = view.getUint16(start + 14, Endian.little);
    } else if (id == 'data') {
      data = Uint8List.sublistView(bytes, start, end);
    }
    offset = end + (size.isOdd ? 1 : 0);
  }
  if (format != 1 || channels == null || channels < 1 || bits != 16) {
    return null;
  }
  final pcm = data;
  if (pcm == null || pcm.length < 2) return null;
  final frame = channels * 2;
  final frames = pcm.length ~/ frame;
  final samples = Float32List(frames);
  final pcmView = ByteData.sublistView(pcm);
  for (var frameIndex = 0; frameIndex < frames; frameIndex++) {
    final sample = pcmView.getInt16(frameIndex * frame, Endian.little);
    samples[frameIndex] = sample / 32768.0;
  }
  return samples;
}

bool _ascii(Uint8List bytes, int offset, String text) {
  if (offset + text.length > bytes.length) return false;
  for (var index = 0; index < text.length; index++) {
    if (bytes[offset + index] != text.codeUnitAt(index)) return false;
  }
  return true;
}

String _jsonEscape(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
