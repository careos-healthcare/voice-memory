import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_milestone/archive_milestone_engine.dart';
import 'package:voicememory_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry({required String id, required DateTime createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: 'Reflection about work and focus.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Noticed a pattern',
      repeatedSignal: 'signal',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  test('empty entries yields no milestones and empty copy constant', () {
    final view = buildArchiveMilestones(
      entries: [],
      currentBeliefText: 'Belief A',
    );
    expect(view.hasMeaningfulShifts, isFalse);
    expect(view.latest, isNull);
    expect(archiveMilestonesEmptyCopy, contains('No meaningful archive shifts'));
  });

  test('does not fabricate first reflection or count milestones', () {
    final entries = [
      _entry(id: '1', createdAt: DateTime(2025, 1, 1)),
      _entry(id: '2', createdAt: DateTime(2025, 1, 2)),
    ];
    final view = buildArchiveMilestones(
      entries: entries,
      currentBeliefText: 'Working belief',
      baseline: ArchiveStateSnapshot(
        belief: 'Working belief',
        confidence: 72,
        reputation: 'developing',
        evidenceCount: 2,
        lifeAreas: [],
        timestamp: DateTime(2025, 1, 2).toIso8601String(),
      ),
    );
    expect(view.milestones, isEmpty);
    expect(view.milestones.any((m) => m.type == 'FIRST_REFLECTION'), isFalse);
    expect(view.milestones.any((m) => m.type == 'TEN_REFLECTIONS'), isFalse);
  });

  test('belief shift from snapshot uses real before/after text', () {
    final entries = [
      _entry(id: '1', createdAt: DateTime(2025, 3, 1)),
    ];
    final view = buildArchiveMilestones(
      entries: entries,
      currentBeliefText: 'New belief after more evidence.',
      baseline: ArchiveStateSnapshot(
        belief: 'Earlier working belief.',
        confidence: 55,
        reputation: 'developing',
        evidenceCount: 1,
        lifeAreas: [],
        timestamp: '2025-03-01T12:00:00.000Z',
      ),
    );
    expect(view.milestones.length, 1);
    expect(view.milestones.first.type, 'FIRST_BELIEF_CHANGE');
    expect(view.milestones.first.explanation, contains('Earlier working belief'));
    expect(view.milestones.first.explanation, contains('New belief after more evidence'));
    expect(view.milestones.first.periodLabel, isNot('Recently'));
  });

  test('reputation delta row produces archive changed milestone', () {
    final entries = [
      _entry(id: '1', createdAt: DateTime(2025, 4, 1)),
      _entry(id: '2', createdAt: DateTime(2025, 4, 2)),
    ];
    final delta = ArchiveStateDeltaView(
      hasChanges: true,
      rows: [
        ArchiveStateDeltaRow(
          label: 'Reputation',
          then: 'Low',
          now: 'Developing',
          difference: 'Low → Developing',
        ),
      ],
      headline: 'What changed since you last looked',
      awayReturn: false,
    );
    final view = buildArchiveMilestones(
      entries: entries,
      currentBeliefText: 'Same belief text.',
      baseline: ArchiveStateSnapshot(
        belief: 'Same belief text.',
        confidence: 40,
        reputation: 'low',
        evidenceCount: 1,
        lifeAreas: [],
        timestamp: '2025-04-02T10:00:00.000Z',
      ),
      delta: delta,
    );
    expect(view.milestones.length, 1);
    expect(view.milestones.first.type, 'ARCHIVE_CHANGED_ITS_MIND');
    expect(view.milestones.first.explanation, contains('Low → Developing'));
  });
}
