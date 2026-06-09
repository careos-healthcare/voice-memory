import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/retention/archive_discovery_service.dart';
import 'package:voicememory_mobile/features/retention/archive_progress_identity.dart';
import 'package:voicememory_mobile/features/weekly_story/weekly_story_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'dart:io';

import 'package:voicememory_mobile/features/discover/belief_engine.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — transcript padding for evidence threshold here.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('first recording shows learning belief without inflated confidence', () {
    final entries = [
      _entry(
        id: '1',
        at: DateTime.now(),
        line: 'I feel uncertain about work',
      ),
    ];
    final card = const DiscoverBeliefEngine().build(entries: entries);
    expect(card == null || card.confidencePercent < 60, isTrue);
  });

  test('progress identity counts scale with entries', () {
    final entries = List.generate(
      6,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 1, i + 1),
        line: 'Reflection $i about confidence and work',
        themes: const ['confidence', 'work'],
      ),
    );
    final identity = const ArchiveProgressIdentityBuilder().build(entries);
    expect(identity.recordings, 6);
    expect(identity.themesDiscovered, greaterThanOrEqualTo(1));
    expect(identity.archiveAgeDays, greaterThanOrEqualTo(0));
  });

  test('weekly story requires at least five entries', () {
    final few = List.generate(
      4,
      (i) => _entry(id: 'e$i', at: DateTime(2026, 3, i + 1), line: 'Line $i'),
    );
    expect(const WeeklyStoryEngine().build(entries: few), isNull);

    final anchor = DateTime(2026, 5, 20);
    final enough = List.generate(
      6,
      (i) => _entry(
        id: 'e$i',
        at: anchor.subtract(Duration(days: i)),
        line: 'Confidence and work reflection $i',
        themes: const ['confidence'],
      ),
    );
    final story = const WeeklyStoryEngine().build(entries: enough, now: anchor);
    expect(story, isNotNull);
    expect(story!.topThemes, isNotEmpty);
  });

  test('discovery banner hidden after viewed fingerprint', () async {
    final dir = await Directory.systemTemp.createTemp('vm_prefs_test');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = ArchiveDiscoveryService(prefs);

    final entries = List.generate(
      6,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 5, i + 1),
        line: 'I need more confidence at work today',
        themes: const ['confidence', 'work'],
      ),
    );

    final first = await service.loadActiveNotice(entries: entries);
    expect(first, isNotNull);

    await service.acknowledgeDiscovery(
      entries: entries,
      state: null,
      viewedAt: DateTime.now(),
    );

    final second = await service.loadActiveNotice(entries: entries);
    expect(second, isNull);
  });

  test('weekly story growing themes use real counts', () {
    final now = DateTime(2026, 5, 25);
    final entries = <JournalEntry>[
      ...List.generate(
        3,
        (i) => _entry(
          id: 'old$i',
          at: now.subtract(Duration(days: 10 + i)),
          line: 'Old stress mention',
          themes: const ['stress'],
        ),
      ),
      ...List.generate(
        5,
        (i) => _entry(
          id: 'new$i',
          at: now.subtract(Duration(days: i)),
          line: 'Confidence growing at work',
          themes: const ['confidence'],
        ),
      ),
    ];
    final story = const WeeklyStoryEngine().build(entries: entries, now: now);
    expect(story, isNotNull);
    expect(
      story!.growingThemes.any((t) => t.label == 'Confidence'),
      isTrue,
    );
  });
}
