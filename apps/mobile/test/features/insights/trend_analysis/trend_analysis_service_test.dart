import 'dart:io';
import '../../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_aggregator.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_onnx_synthesizer.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_report_store.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_service.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSynthesizer extends TrendAnalysisOnnxSynthesizer {
  _FakeSynthesizer()
    : super(
        reflectionModel: LocalReflectionDataSource(
          inference: const LocalReflectionHeuristicInference(),
        ),
      );

  @override
  Future<({ReflectionDto reflection, bool usedOnnx})> synthesize(
    TrendAggregatedMetadata metadata,
  ) async {
    return (
      reflection: ReflectionDto(
        mood: 'reflective',
        emotionalIntensity: metadata.averageIntensity.round().clamp(1, 10),
        recurringThemes: metadata.themeCounts.keys.take(2).toList(),
        concreteObservation:
            'This week your archive shows rising intensity around work.',
        repeatedSignal: 'Work pressure keeps returning.',
        tensionOrContradiction:
            metadata.underlyingTensions.firstOrNull?.label ?? '',
        patternObservations: metadata.cognitivePatterns
            .map((pattern) => pattern.label)
            .take(2)
            .toList(),
      ),
      usedOnnx: false,
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => length == 0 ? null : first;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('generates and caches weekly report from drift records', () async {
    final dir = await Directory.systemTemp.createTemp('trend_analysis_service_');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final sqlite = await openTestAppSqliteDatabase();
    final db = AppDatabase.fromSqflite(sqlite.database);

    await db.customInsert(
      '''
      INSERT INTO journal_entries (
        id, created_at, updated_at, deleted_at, is_archived,
        transcript, has_verified_proof, payload_json
      ) VALUES (?, ?, ?, NULL, 0, ?, 0, ?)
      ''',
      variables: [
        Variable<String>('entry-1'),
        Variable<int>(DateTime.utc(2026, 8, 14).millisecondsSinceEpoch),
        Variable<int>(DateTime.utc(2026, 8, 14).millisecondsSinceEpoch),
        Variable<String>('Work kept spilling into the evening.'),
        Variable<String>(
          '{"reflection":{"mood":"anxious","emotionalIntensity":6,'
          '"recurringThemes":["work"],'
          '"exactLanguagePattern":"","concreteObservation":"Too much work",'
          '"repeatedSignal":"","tensionOrContradiction":"Need rest but say yes"}}',
        ),
      ],
    );
    await db.customInsert(
      '''
      INSERT INTO journal_entries (
        id, created_at, updated_at, deleted_at, is_archived,
        transcript, has_verified_proof, payload_json
      ) VALUES (?, ?, ?, NULL, 0, ?, 0, ?)
      ''',
      variables: [
        Variable<String>('entry-2'),
        Variable<int>(DateTime.utc(2026, 8, 15).millisecondsSinceEpoch),
        Variable<int>(DateTime.utc(2026, 8, 15).millisecondsSinceEpoch),
        Variable<String>('Still overwhelmed by deadlines.'),
        Variable<String>(
          '{"reflection":{"mood":"overwhelmed","emotionalIntensity":8,'
          '"recurringThemes":["work"],'
          '"exactLanguagePattern":"","concreteObservation":"Deadlines stack",'
          '"repeatedSignal":"","patternObservations":["Language loops without resolving"]}}',
        ),
      ],
    );
    await db.customInsert(
      '''
      INSERT INTO journal_entries (
        id, created_at, updated_at, deleted_at, is_archived,
        transcript, has_verified_proof, payload_json
      ) VALUES (?, ?, ?, NULL, 0, ?, 0, ?)
      ''',
      variables: [
        Variable<String>('entry-3'),
        Variable<int>(DateTime.utc(2026, 8, 16).millisecondsSinceEpoch),
        Variable<int>(DateTime.utc(2026, 8, 16).millisecondsSinceEpoch),
        Variable<String>('I avoided the hard conversation again.'),
        Variable<String>(
          '{"reflection":{"mood":"frustrated","emotionalIntensity":7,'
          '"recurringThemes":["conflict"],'
          '"exactLanguagePattern":"","concreteObservation":"Avoidance again",'
          '"repeatedSignal":""}}',
        ),
      ],
    );

    final service = TrendAnalysisService(
      journalDatabase: db,
      reportStore: TrendAnalysisReportStore(prefs),
      aggregator: const TrendAnalysisAggregator(minReflections: 3),
      synthesizer: _FakeSynthesizer(),
    );

    final report = await service.flush(window: TrendAnalysisWindow.sevenDay);
    expect(report, isNotNull);
    expect(report!.reflectionCount, 3);
    expect(report.summary, contains('rising intensity'));
    expect(report.emotionalShifts, isNotEmpty);
    expect(report.cognitiveLoops, isNotEmpty);

    final cached = await service.getCachedReport(TrendAnalysisWindow.sevenDay);
    expect(cached?.summary, report.summary);

    service.dispose();
    await dir.delete(recursive: true);
  });
}
