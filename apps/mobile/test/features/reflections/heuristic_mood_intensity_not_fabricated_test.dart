import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_aggregator.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_onnx_synthesizer.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_confidence.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_model_contract.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_output_parser.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/journal_conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// The heuristic extractor is the production reflection path: no ONNX model is
/// bundled, so every on-device entry is parsed from these logits. Mood and
/// emotional intensity used to be synthesised from a hash of the transcript
/// (`sin()` of the token density, and that density modulo 1000), which is
/// indistinguishable from a real reading at the point of display.
///
/// These tests pin the two guarantees that matter:
/// 1. The heuristic never emits a mood or intensity value.
/// 2. The genuinely text-derived outputs still work.
void main() {
  const heuristic = LocalReflectionHeuristicInference();

  const tensionAndAction =
      'Work has been heavy but I keep taking on more. '
      'Tomorrow I will leave on time and rest.';

  Future<ReflectionDto> reflectFor(String transcript) async {
    final logits = await heuristic.runForTranscript(transcript);
    return ReflectionOutputParser.toReflectionDto(
      transcript: transcript,
      logits: logits,
    );
  }

  group('heuristic emits no mood or intensity', () {
    test('mood logits stay unset for any transcript', () async {
      for (final transcript in const [
        tensionAndAction,
        'I keep circling the same decision about money and sleep.',
        'Nothing much happened today, I just kept going and going.',
      ]) {
        final logits = await heuristic.runForTranscript(transcript);
        final mood = logits.sublist(
          ReflectionModelContract.moodLogitStart,
          ReflectionModelContract.moodLogitStart +
              ReflectionModelContract.moodLogitCount,
        );
        expect(
          mood,
          everyElement(0.0),
          reason: 'mood must not be synthesised from transcript hash',
        );
        expect(
          logits[ReflectionModelContract.intensityLogitIndex],
          0.0,
          reason: 'intensity must not be synthesised from transcript hash',
        );
      }
    });

    test('parsed reflection reports mood and intensity as unknown', () async {
      final reflection = await reflectFor(tensionAndAction);
      expect(reflection.mood, isEmpty);
      expect(reflection.emotionalIntensity, 0);
    });

    test('no transcript produces a differing mood or intensity', () async {
      final a = await reflectFor(tensionAndAction);
      final b = await reflectFor(
        'I felt completely overwhelmed and furious about the deadline today.',
      );
      expect(a.mood, b.mood);
      expect(a.emotionalIntensity, b.emotionalIntensity);
    });

    test('confidence no longer rewards a fabricated intensity', () {
      const bare = ReflectionDto(mood: '', emotionalIntensity: 0);
      const withIntensity = ReflectionDto(mood: 'calm', emotionalIntensity: 7);
      expect(
        LocalAiConfidence.reflectionConfidence(
          reflection: bare,
          usedOnnx: false,
        ),
        LocalAiConfidence.reflectionConfidence(
          reflection: withIntensity,
          usedOnnx: false,
        ),
        reason: 'an intensity value must not buy confidence on its own',
      );
    });
  });

  group('downstream consumers treat unknown as absent', () {
    JournalEntry entryWith(Reflection reflection, {int revision = 1}) =>
        JournalEntry(
          id: 'entry-1',
          createdAt: DateTime.utc(2026),
          transcript: 'hello there, this is a saved entry',
          durationSeconds: 5,
          reflection: reflection,
          revision: revision,
          changeId: 'change-$revision',
        );

    const unread = Reflection(
      mood: ReflectionModelContract.unknownMood,
      emotionalIntensity: ReflectionModelContract.unknownIntensity,
      recurringThemes: ['work'],
      exactLanguagePattern: 'a',
      concreteObservation: 'b',
      repeatedSignal: 'c',
    );
    const measured = Reflection(
      mood: 'anxious',
      emotionalIntensity: 8,
      recurringThemes: ['work'],
      exactLanguagePattern: 'a',
      concreteObservation: 'b',
      repeatedSignal: 'c',
    );

    test('sync merge never lets an unread value overwrite a real one', () {
      // Local is an on-device extraction, remote came back from the analyzer.
      final merged = JournalConflictResolver.resolve(
        local: entryWith(unread, revision: 2),
        remote: entryWith(measured, revision: 2),
        policy: JournalCollisionPolicy.preferLocal,
      );

      expect(merged.entry.reflection.mood, 'anxious');
      expect(merged.entry.reflection.emotionalIntensity, 8);
    });

    test('trend analysis reports no intensity direction without readings', () {
      TrendReflectionRecord record(int index) => TrendReflectionRecord(
        entryId: 'e$index',
        createdAt: DateTime.utc(2026, 1, index + 1),
        mood: ReflectionModelContract.unknownMood,
        emotionalIntensity: ReflectionModelContract.unknownIntensity,
        recurringThemes: const ['work'],
        concreteObservation: 'observed something',
      );

      final metadata = const TrendAnalysisAggregator().aggregate(
        window: TrendAnalysisWindow.sevenDay,
        windowStart: DateTime.utc(2026),
        windowEnd: DateTime.utc(2026, 2),
        records: List.generate(4, record),
      );

      expect(metadata, isNotNull);
      expect(metadata!.intensityTrend, TrendIntensityDirection.unknown);
      expect(metadata.averageIntensity, 0);
      expect(
        metadata.moodCounts,
        isEmpty,
        reason: 'an unread mood must not become a counted mood label',
      );

      // The weekly report is the surface that rendered these numbers.
      final report = TrendAnalysisOnnxSynthesizer(
        reflectionModel: LocalReflectionDataSource(
          inference: heuristic,
        ),
      ).composeReport(
        metadata: metadata,
        synthesis: const ReflectionDto(mood: '', emotionalIntensity: 0),
        usedOnnx: false,
      );

      final rendered = [
        report.summary,
        for (final shift in report.emotionalShifts) ...[
          shift.headline,
          shift.detail,
        ],
      ].join('\n').toLowerCase();

      expect(
        rendered,
        isNot(contains('intensity')),
        reason: 'no intensity line may render without a reading behind it',
      );
      expect(rendered, isNot(contains('mood')));
      expect(rendered, isNot(contains('0.0')));
    });
  });

  group('text-derived signal survives', () {
    test('theme hints still come from literal matches', () async {
      final reflection = await reflectFor(
        'My work and my sleep are both suffering because of money stress.',
      );
      expect(
        reflection.recurringThemes,
        containsAll(<String>['work', 'sleep']),
      );
    });

    test('tension and action spans still resolve', () async {
      final logits = await heuristic.runForTranscript(tensionAndAction);
      expect(
        logits[ReflectionModelContract.tensionSpanEndIndex],
        greaterThan(logits[ReflectionModelContract.tensionSpanStartIndex]),
      );
      expect(
        logits[ReflectionModelContract.actionSpanEndIndex],
        greaterThan(logits[ReflectionModelContract.actionSpanStartIndex]),
      );

      final reflection = await reflectFor(tensionAndAction);
      expect(reflection.tensionOrContradiction, isNotNull);
      expect(reflection.nextSmallAction, isNotNull);
    });

    test("contrast pattern hint fires on ' but '", () async {
      final logits = await heuristic.runForTranscript(tensionAndAction);
      expect(
        logits[ReflectionModelContract.patternLogitStart + 3],
        greaterThan(0.45),
      );
      final reflection = await reflectFor(tensionAndAction);
      expect(
        reflection.patternObservations,
        contains('Contrast marker ("but") shifts the sentence.'),
      );
    });

    test('hedging pattern hint fires on maybe / kind of', () async {
      const hedged = 'Maybe I am kind of avoiding the conversation entirely.';
      final logits = await heuristic.runForTranscript(hedged);
      expect(
        logits[ReflectionModelContract.patternLogitStart + 4],
        greaterThan(0.45),
      );
      final reflection = await reflectFor(hedged);
      expect(
        reflection.patternObservations,
        contains('Vague referent instead of a concrete noun.'),
      );
    });

    test('knowledge graph still builds from spans and themes', () async {
      final source = await LocalReflectionDataSource.create();
      final result = await source.inferFromTranscript(
        entryId: 'offline-entry',
        transcript: tensionAndAction,
      );

      expect(result.usedOnnx, isFalse);
      expect(result.reflection.mood, isEmpty);
      expect(result.reflection.emotionalIntensity, 0);
      expect(result.knowledgeGraph.tensionOrContradiction, isNotNull);
      expect(result.knowledgeGraph.nextSmallAction, isNotNull);
      expect(result.knowledgeGraph.edges, isNotEmpty);
    });
  });
}
