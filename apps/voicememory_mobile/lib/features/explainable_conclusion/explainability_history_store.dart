import 'dart:async';
import 'dart:io';

import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'explainable_conclusion.dart';
import 'explainable_conclusion_validator.dart';

class ExplainabilityHistoryEntry {
  const ExplainabilityHistoryEntry({
    required this.conclusion,
    required this.appendedAt,
  });

  final ExplainableConclusion conclusion;
  final DateTime appendedAt;

  Map<String, dynamic> toJson() => {
    'conclusion': conclusion.toJson(),
    'appendedAt': appendedAt.toUtc().toIso8601String(),
  };

  static ExplainabilityHistoryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final conclusion = ExplainableConclusion.fromJson(json['conclusion']);
    final appendedAt = DateTime.tryParse(json['appendedAt']?.toString() ?? '');
    if (conclusion == null || appendedAt == null) return null;
    return ExplainabilityHistoryEntry(
      conclusion: conclusion,
      appendedAt: appendedAt,
    );
  }
}

class ExplainabilityHistoryStore {
  ExplainabilityHistoryStore({
    required File file,
    required PrivateDataEncryptionKeyStore keyStore,
    this.maxEntries = 200,
  }) : assert(maxEntries > 0),
       _storage = EncryptedJsonFileStore(file: file, keyStore: keyStore);

  static const storeVersion = 1;

  final EncryptedJsonFileStore _storage;
  final int maxEntries;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  File get encryptedFile => _storage.file;

  Future<ExplainabilityHistoryEntry> append(
    ValidatedExplainableConclusion validated,
  ) {
    return _serialized(() async {
      final current = await _readAll();
      final priorVersions = current
          .where((item) => item.conclusion.id == validated.value.id)
          .map((item) => item.conclusion.historyVersion);
      final nextVersion = priorVersions.isEmpty
          ? 1
          : priorVersions.reduce((a, b) => a > b ? a : b) + 1;
      final source = validated.value;
      final versioned = ExplainableConclusion(
        id: source.id,
        statement: source.statement,
        confidence: source.confidence,
        reasoning: source.reasoning,
        uncertaintyNote: source.uncertaintyNote,
        evidence: source.evidence,
        alternatives: source.alternatives,
        provenance: ExplainableConclusionProvenance(
          source: source.provenance.source,
          generatedAt: source.provenance.generatedAt,
          schemaVersion: source.provenance.schemaVersion,
          model: source.provenance.model,
          sourceRevision: source.provenance.sourceRevision,
          parentVersion: nextVersion == 1 ? null : nextVersion - 1,
        ),
        kind: source.kind,
        nextRecordingPrompt: source.nextRecordingPrompt,
        historyVersion: nextVersion,
        isLegacy: source.isLegacy,
        confidenceKnown: source.confidenceKnown,
        feedbackState: source.feedbackState,
        feedbackTimestamp: source.feedbackTimestamp,
        correctionNote: source.correctionNote,
        theoryId: source.theoryId,
        evolutionHistory: source.evolutionHistory,
      );
      final entry = ExplainabilityHistoryEntry(
        conclusion: versioned,
        appendedAt: DateTime.now().toUtc(),
      );
      final next = [...current, entry];
      if (next.length > maxEntries) {
        next.removeRange(0, next.length - maxEntries);
      }
      await _writeAll(next);
      return entry;
    });
  }

  /// Records a generated version once, including across cache reads/restarts.
  Future<ExplainabilityHistoryEntry> appendIfAbsent(
    ValidatedExplainableConclusion validated,
  ) {
    return _serialized(() async {
      final current = await _readAll();
      final source = validated.value;
      for (final item in current.reversed) {
        final prior = item.conclusion;
        if (prior.id == source.id &&
            prior.statement == source.statement &&
            prior.confidence == source.confidence &&
            prior.uncertaintyNote == source.uncertaintyNote &&
            prior.evidence.map((item) => item.toJson()).toString() ==
                source.evidence.map((item) => item.toJson()).toString() &&
            prior.alternatives.map((item) => item.toJson()).toString() ==
                source.alternatives.map((item) => item.toJson()).toString() &&
            prior.provenance.generatedAt.toUtc() ==
                source.provenance.generatedAt.toUtc() &&
            prior.provenance.sourceRevision ==
                source.provenance.sourceRevision) {
          return item;
        }
      }
      final priorVersions = current
          .where((item) => item.conclusion.id == source.id)
          .map((item) => item.conclusion.historyVersion);
      final nextVersion = priorVersions.isEmpty
          ? 1
          : priorVersions.reduce((a, b) => a > b ? a : b) + 1;
      final versioned = ExplainableConclusion(
        id: source.id,
        statement: source.statement,
        confidence: source.confidence,
        reasoning: source.reasoning,
        uncertaintyNote: source.uncertaintyNote,
        evidence: source.evidence,
        alternatives: source.alternatives,
        provenance: ExplainableConclusionProvenance(
          source: source.provenance.source,
          generatedAt: source.provenance.generatedAt,
          schemaVersion: source.provenance.schemaVersion,
          model: source.provenance.model,
          sourceRevision: source.provenance.sourceRevision,
          parentVersion: nextVersion == 1 ? null : nextVersion - 1,
        ),
        historyVersion: nextVersion,
        isLegacy: source.isLegacy,
        confidenceKnown: source.confidenceKnown,
        feedbackState: source.feedbackState,
        feedbackTimestamp: source.feedbackTimestamp,
        correctionNote: source.correctionNote,
        theoryId: source.theoryId,
        evolutionHistory: source.evolutionHistory,
      );
      final entry = ExplainabilityHistoryEntry(
        conclusion: versioned,
        appendedAt: DateTime.now().toUtc(),
      );
      final next = [...current, entry];
      if (next.length > maxEntries) {
        next.removeRange(0, next.length - maxEntries);
      }
      await _writeAll(next);
      return entry;
    });
  }

  Future<List<ExplainabilityHistoryEntry>> byConclusionId(String id) =>
      _serialized(() async {
        final all = await _readAll();
        return List.unmodifiable(
          all.where((item) => item.conclusion.id == id).toList()..sort(
            (a, b) => b.conclusion.historyVersion.compareTo(
              a.conclusion.historyVersion,
            ),
          ),
        );
      });

  Future<List<ExplainabilityHistoryEntry>> all() =>
      _serialized(() async => List.unmodifiable(await _readAll()));

  Future<void> clear() => _serialized(() => _writeAll(const []));

  /// Content-free export suitable for diagnostics and support attachments.
  Future<Map<String, dynamic>> exportPrivacySafe() => _serialized(() async {
    final all = await _readAll();
    return {
      'storeVersion': storeVersion,
      'entries': [
        for (final item in all)
          {
            'conclusionId': item.conclusion.id,
            'historyVersion': item.conclusion.historyVersion,
            'appendedAt': item.appendedAt.toUtc().toIso8601String(),
            'confidence': item.conclusion.confidence,
            'evidenceCount': item.conclusion.evidence.length,
            'evidenceEntryIds': item.conclusion.evidence
                .map((citation) => citation.entryId)
                .toSet()
                .toList(),
            'source': item.conclusion.provenance.source,
            'schemaVersion': item.conclusion.provenance.schemaVersion,
          },
      ],
    };
  });

  Future<void> dispose() async {
    _disposed = true;
    await _pending;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    if (_disposed) {
      return Future.error(StateError('ExplainabilityHistoryStore is disposed'));
    }
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<ExplainabilityHistoryEntry>> _readAll() async {
    final raw = await _storage.readJson();
    if (raw == null) return [];
    if (raw is! Map) throw const FormatException('Invalid history envelope');
    final json = Map<String, dynamic>.from(raw);
    if (json['storeVersion'] != storeVersion) {
      throw FormatException(
        'Unsupported explainability history version: ${json['storeVersion']}',
      );
    }
    return (json['entries'] as List? ?? const [])
        .map(ExplainabilityHistoryEntry.fromJson)
        .whereType<ExplainabilityHistoryEntry>()
        .toList();
  }

  Future<void> _writeAll(List<ExplainabilityHistoryEntry> entries) =>
      _storage.writeJson({
        'storeVersion': storeVersion,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      });
}
