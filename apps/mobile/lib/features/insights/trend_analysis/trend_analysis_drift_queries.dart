import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:drift/drift.dart';

/// Drift queries for reflection-bearing journal rows in a rolling window.
abstract final class TrendAnalysisDriftQueries {
  TrendAnalysisDriftQueries._();

  static Future<List<TrendReflectionRecord>> fetchReflectionRecordsInWindow(
    JournalDatabase db, {
    required DateTime windowStart,
    required DateTime windowEnd,
    int limit = 256,
  }) async {
    final startMillis = windowStart.toUtc().millisecondsSinceEpoch;
    final endMillis = windowEnd.toUtc().millisecondsSinceEpoch;

    final rows = await db.customSelect(
      '''
      SELECT
        id,
        created_at,
        transcript,
        payload_json
      FROM ${DatabaseConstants.journalEntriesTable}
      WHERE deleted_at IS NULL
        AND created_at >= ?
        AND created_at <= ?
      ORDER BY created_at ASC, id ASC
      LIMIT ?
      ''',
      variables: [
        Variable<int>(startMillis),
        Variable<int>(endMillis),
        Variable<int>(limit),
      ],
      readsFrom: {db.journalEntries},
    ).get();

    return rows
        .map(_mapRow)
        .where((record) => record.hasUsableReflection)
        .toList(growable: false);
  }

  static TrendReflectionRecord _mapRow(QueryRow row) {
    final entryId = row.read<String>('id');
    final createdAtMillis = row.read<int>('created_at');
    final transcript = row.read<String>('transcript');
    final payloadJson = row.read<String>('payload_json');
    final reflection = _reflectionFromPayload(payloadJson);

    return TrendReflectionRecord(
      entryId: entryId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis, isUtc: true),
      mood: reflection.mood,
      emotionalIntensity: reflection.emotionalIntensity,
      recurringThemes: reflection.recurringThemes,
      tensionOrContradiction: reflection.tensionOrContradiction,
      patternObservations: reflection.patternObservations,
      concreteObservation: reflection.concreteObservation,
      transcript: transcript,
    );
  }

  static Reflection _reflectionFromPayload(String payloadJson) {
    if (payloadJson.trim().isEmpty) {
      return _emptyReflection();
    }

    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) return _emptyReflection();
      final payload = Map<String, dynamic>.from(decoded);
      final reflectionJson = payload['reflection'];
      if (reflectionJson is Map<String, dynamic>) {
        return Reflection.fromJson(reflectionJson);
      }
      if (payload.containsKey('mood')) {
        return Reflection.fromJson(payload);
      }
    } on Object {
      return _emptyReflection();
    }
    return _emptyReflection();
  }

  static Reflection _emptyReflection() {
    return const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    );
  }
}
