import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/memory_resurfacing/memory_resurfacing_service.dart';
import 'package:voicememory_mobile/features/memory_resurfacing/memory_resurfacing_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'dart:io';

JournalEntry _oldEntry({
  required String id,
  required DateTime createdAt,
  List<String> themes = const ['work'],
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: 'I keep taking on too much at work',
    durationSeconds: 40,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: 'too much at work',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('selectCards picks old theme-linked never-resurfaced entries', () async {
    final dir = await Directory.systemTemp.createTemp('vm_resurfacing_test');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));

    final now = DateTime(2026, 5, 1);
    final entries = [
      _oldEntry(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 200)),
        themes: const ['work'],
      ),
      _oldEntry(
        id: 'recent',
        createdAt: now.subtract(const Duration(days: 5)),
        themes: const ['work'],
      ),
      JournalEntry(
        id: 'other',
        createdAt: now.subtract(const Duration(days: 200)),
        transcript: 'I want to spend more time traveling abroad',
        durationSeconds: 40,
        reflection: Reflection(
          mood: '',
          emotionalIntensity: 0,
          recurringThemes: const ['travel'],
          exactLanguagePattern: 'time traveling abroad',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
    ];

    final cards = await service.selectCards(
      entries: entries,
      currentBelief: 'You carry too much at work',
      limit: 3,
      now: now,
    );

    expect(cards.length, 1);
    expect(cards.first.entry.id, 'old');
    expect(cards.first.headline, contains('months ago'));
  });

  test('markShown and markOpened update stats', () async {
    final dir = await Directory.systemTemp.createTemp('vm_resurfacing_stats');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));

    await service.markShown(['a', 'b']);
    await service.markOpened('a');

    final stats = await service.stats();
    expect(stats.resurfacedCount, 2);
    expect(stats.openedCount, 1);

    final cards = await service.selectCards(
      entries: [_oldEntry(id: 'a', createdAt: DateTime(2025, 1, 1))],
      limit: 5,
      now: DateTime(2026, 5, 1),
    );
    expect(cards, isEmpty);
  });

  test('resurfacingHeadline uses months for sub-year age', () {
    final now = DateTime(2026, 6, 1);
    final created = DateTime(2025, 11, 1);
    expect(resurfacingHeadline(created, now), 'You said this 7 months ago.');
  });
}
