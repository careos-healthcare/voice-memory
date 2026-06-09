import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/contradiction_detection/contradiction_detection_service.dart';
import 'package:voicememory_mobile/features/contradiction_detection/contradiction_report.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — additional transcript padding for evidence threshold.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('detects networking hate vs career positive reversal', () {
    final result = const ContradictionDetectionService().detect(
      entries: [
        _entry(
          id: 'old',
          at: DateTime(2025, 1, 10),
          line: 'I hate networking events',
          themes: const ['networking'],
        ),
        _entry(
          id: 'new',
          at: DateTime(2026, 2, 1),
          line: 'Networking changed my career',
          themes: const ['networking', 'career'],
        ),
        ...List.generate(
          3,
          (i) => _entry(
            id: 'pad$i',
            at: DateTime(2025, 6, i + 1),
            line: 'Neutral filler reflection with enough transcript text.',
          ),
        ),
      ],
    );

    expect(result.hasPossibleBeliefChange, isTrue);
    final top = result.reports.first;
    expect(top.originalStatement.toLowerCase(), contains('hate'));
    expect(top.conflictingStatement.toLowerCase(), contains('networking'));
    expect(top.confidenceScore, greaterThan(60));
    expect(top.recordingIds, containsAll(['old', 'new']));
    expect(top.kind, ContradictionKind.reversedTheme);
  });

  test('detects gradual shift from uncomfortable to positive wording', () {
    final result = const ContradictionDetectionService().detect(
      entries: [
        _entry(
          id: 'mid',
          at: DateTime(2025, 9, 1),
          line: 'Networking is uncomfortable but I keep showing up',
          themes: const ['networking'],
        ),
        _entry(
          id: 'new',
          at: DateTime(2026, 2, 1),
          line: 'Networking changed my career and I am grateful',
          themes: const ['networking', 'career'],
        ),
        ...List.generate(
          3,
          (i) => _entry(
            id: 'pad$i',
            at: DateTime(2025, 6, i + 1),
            line: 'Neutral filler reflection with enough transcript text.',
          ),
        ),
      ],
    );

    expect(
      result.reports.any((r) => r.kind == ContradictionKind.gradualShift),
      isTrue,
    );
  });

  test('returns empty when fewer than two eligible entries', () {
    final result = const ContradictionDetectionService().detect(
      entries: [
        _entry(
          id: 'only',
          at: DateTime(2026, 1, 1),
          line: 'I hate networking events',
        ),
      ],
    );
    expect(result.reports, isEmpty);
  });

  test('ContradictionReport round-trips JSON', () {
    const report = ContradictionReport(
      id: 'ctr-1',
      originalStatement: 'I hate networking',
      conflictingStatement: 'Networking changed my career',
      confidenceScore: 82,
      originalEntryId: 'a',
      conflictingEntryId: 'b',
      kind: ContradictionKind.reversedTheme,
      sharedThemes: ['networking'],
    );
    final json = report.toJson();
    final parsed = ContradictionReport.fromJson(json);
    expect(parsed?.confidenceScore, 82);
    expect(parsed?.recordingIds, ['a', 'b']);
  });
}
