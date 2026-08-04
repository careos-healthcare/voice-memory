// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/search/local_text_embedding.dart';
import '../../models/journal_entry.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'archive_semantic_search_models.dart';

/// Encrypted, text-free entry embedding index.
///
/// Only opaque journal IDs, revisions, safe timestamps, and normalized vectors
/// are persisted. Journal text is supplied transiently to [reconcile].
final class SemanticIndexStore {
  SemanticIndexStore({
    required EncryptedJsonFileStore storage,
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
    this.driverId = 'hashed-local-semantic-v2',
    this.schemaVersion = 1,
    this.governanceVersion = 1,
    this.yieldEvery = 24,
  }) : _storage = storage,
       _embeddingDriver = embeddingDriver;

  final EncryptedJsonFileStore _storage;
  final LocalEmbeddingDriver _embeddingDriver;
  final String driverId;
  final int schemaVersion;
  final int governanceVersion;
  final int yieldEvery;
  Future<void> _writeTail = Future<void>.value();
  bool _disposed = false;

  int get dimensions => _embeddingDriver.dimensions;

  Future<void> reconcile(List<JournalEntry> entries) {
    if (_disposed) return Future.error(StateError('Index store is disposed.'));
    final immutable = List<JournalEntry>.unmodifiable(entries);
    final operation = _writeTail
        .catchError((Object _) {})
        .then((_) => _reconcileNow(immutable));
    _writeTail = operation;
    return operation;
  }

  Future<SemanticIndexSnapshot> loadSnapshot() async {
    await _writeTail.catchError((Object _) {});
    if (_disposed) throw StateError('Index store is disposed.');
    try {
      final state = await _readValidated();
      return state?.snapshot ?? _emptySnapshot();
    } on Object {
      return _emptySnapshot();
    }
  }

  Future<void> clear() {
    final operation = _writeTail.catchError((Object _) {}).then((_) async {
      if (await _storage.file.exists()) await _storage.file.delete();
    });
    _writeTail = operation;
    return operation;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _writeTail.catchError((Object _) {});
  }

  Future<void> _reconcileNow(List<JournalEntry> entries) async {
    _checkOpen();
    _IndexState? existing;
    try {
      existing = await _readValidated();
    } on Object {
      existing = null;
    }
    final eligible = {
      for (final entry in entries)
        if (_searchableText(entry).trim().isNotEmpty &&
            !entry.transcript.startsWith('[draft]'))
          entry.id: entry,
    };
    final revisions = <String, String>{};
    final vectors = <String, Float32List>{};
    final dates = <String, DateTime>{};
    var embedded = 0;
    for (final item in eligible.entries) {
      final text = _searchableText(item.value);
      final revision = _revision(item.value, text);
      final oldVector = existing?.vectors[item.key];
      if (existing?.revisions[item.key] == revision && oldVector != null) {
        vectors[item.key] = oldVector;
      } else {
        final vector = _embeddingDriver.embed(text);
        _validateVector(vector);
        vectors[item.key] = vector;
        embedded++;
        if (yieldEvery > 0 && embedded % yieldEvery == 0) {
          await Future<void>.delayed(Duration.zero);
          _checkOpen();
        }
      }
      revisions[item.key] = revision;
      dates[item.key] = item.value.createdAt.toUtc();
    }
    await _storage.writeJson({
      'schemaVersion': schemaVersion,
      'governanceVersion': governanceVersion,
      'driverId': driverId,
      'dimensions': dimensions,
      'entries': [
        for (final id in vectors.keys.toList()..sort())
          {
            'id': id,
            'revision': revisions[id],
            'createdAt': dates[id]!.toIso8601String(),
            'vector': vectors[id]!.toList(growable: false),
          },
      ],
    });
  }

  Future<_IndexState?> _readValidated() async {
    final decoded = await _storage.readJson();
    if (decoded == null) return null;
    if (decoded is! Map) throw const FormatException('Invalid index root.');
    final map = Map<String, dynamic>.from(decoded);
    if (map['schemaVersion'] != schemaVersion ||
        map['governanceVersion'] != governanceVersion ||
        map['driverId'] != driverId ||
        map['dimensions'] != dimensions) {
      return null;
    }
    final rows = map['entries'];
    if (rows is! List) throw const FormatException('Invalid index entries.');
    final revisions = <String, String>{};
    final vectors = <String, Float32List>{};
    final dates = <String, DateTime>{};
    for (final raw in rows) {
      if (raw is! Map) throw const FormatException('Invalid index row.');
      final row = Map<String, dynamic>.from(raw);
      final id = row['id'];
      final revision = row['revision'];
      final createdAt = DateTime.tryParse(row['createdAt'] as String? ?? '');
      final values = row['vector'];
      if (id is! String ||
          id.isEmpty ||
          revision is! String ||
          createdAt == null ||
          values is! List ||
          vectors.containsKey(id)) {
        throw const FormatException('Invalid index metadata.');
      }
      final vector = Float32List.fromList(
        values
            .map((value) {
              if (value is! num) throw const FormatException('Invalid vector.');
              return value.toDouble();
            })
            .toList(growable: false),
      );
      _validateVector(vector);
      revisions[id] = revision;
      vectors[id] = vector;
      dates[id] = createdAt.toUtc();
    }
    return _IndexState(revisions: revisions, vectors: vectors, dates: dates);
  }

  void _validateVector(Float32List vector) {
    if (vector.length != dimensions) {
      throw const FormatException('Embedding dimensions do not match.');
    }
    var norm = 0.0;
    for (final value in vector) {
      if (!value.isFinite) throw const FormatException('Non-finite embedding.');
      norm += value * value;
    }
    if (!norm.isFinite || (math.sqrt(norm) - 1).abs() > 0.002) {
      throw const FormatException('Embedding is not normalized.');
    }
  }

  static String _searchableText(JournalEntry entry) => [
    entry.transcript,
    entry.reflection.mood,
    ...entry.reflection.recurringThemes,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.tensionOrContradiction ?? '',
    entry.reflection.avoidedOrVagueArea ?? '',
    entry.reflection.nextSmallAction ?? '',
    ...entry.reflection.patternObservations,
  ].where((value) => value.trim().isNotEmpty).join('\n');

  static String searchableTextFor(JournalEntry entry) => _searchableText(entry);

  String _revision(JournalEntry entry, String text) => sha256
      .convert(
        utf8.encode(
          '$governanceVersion\u0000${entry.createdAt.toUtc().toIso8601String()}'
          '\u0000${entry.reflection.emotionalIntensity}\u0000$text',
        ),
      )
      .toString();

  SemanticIndexSnapshot _emptySnapshot() => SemanticIndexSnapshot(
    vectors: <String, Float32List>{},
    revisions: <String, String>{},
    createdAtById: <String, DateTime>{},
  );

  void _checkOpen() {
    if (_disposed) throw StateError('Index store is disposed.');
  }
}

final class _IndexState {
  const _IndexState({
    required this.revisions,
    required this.vectors,
    required this.dates,
  });

  final Map<String, String> revisions;
  final Map<String, Float32List> vectors;
  final Map<String, DateTime> dates;

  SemanticIndexSnapshot get snapshot => SemanticIndexSnapshot(
    vectors: Map.of(vectors),
    revisions: Map.of(revisions),
    createdAtById: Map.of(dates),
  );
}
