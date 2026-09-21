import 'dart:io';

import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_service.dart';
import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

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

    final now = DateTime(2026, 5);
    final entries = [
      _oldEntry(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 200)),
      ),
      _oldEntry(
        id: 'recent',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      JournalEntry(
        id: 'other',
        createdAt: now.subtract(const Duration(days: 200)),
        transcript: 'I want to spend more time traveling abroad',
        durationSeconds: 40,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 0,
          recurringThemes: ['travel'],
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
      entries: [_oldEntry(id: 'a', createdAt: DateTime(2025))],
      limit: 5,
      now: DateTime(2026, 5),
    );
    expect(cards, isEmpty);
  });

  test('resurfacingHeadline uses months for sub-year age', () {
    final now = DateTime(2026, 6);
    final created = DateTime(2025, 11);
    expect(resurfacingHeadline(created, now), 'You said this 7 months ago.');
  });

  test('selectByAnniversary includes same month/day from previous years',
      () async {
    final dir = await Directory.systemTemp.createTemp('vm_anniversary_match');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));

    final now = DateTime(2026, 5, 18);
    final cards = await service.selectByAnniversary(
      entries: [
        _oldEntry(id: 'last-year', createdAt: DateTime(2025, 5, 18)),
        _oldEntry(id: 'two-years', createdAt: DateTime(2024, 5, 18)),
        _oldEntry(id: 'other-day', createdAt: DateTime(2025, 5, 17)),
      ],
      now: now,
    );

    expect(cards.map((c) => c.entry.id), ['two-years', 'last-year']);
  });

  test('selectByAnniversary excludes the current year', () async {
    final dir = await Directory.systemTemp.createTemp('vm_anniversary_year');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));

    final now = DateTime(2026, 5, 18);
    final cards = await service.selectByAnniversary(
      entries: [
        _oldEntry(id: 'this-year', createdAt: DateTime(2026, 5, 18)),
        _oldEntry(id: 'last-year', createdAt: DateTime(2025, 5, 18)),
      ],
      now: now,
    );

    expect(cards.map((c) => c.entry.id), ['last-year']);
  });

  test('selectByAnniversary does not consult or write store shown-tracking',
      () async {
    final dir = await Directory.systemTemp.createTemp('vm_anniversary_store');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));

    await service.markShown(['last-year']);
    final before = await service.stats();

    final cards = await service.selectByAnniversary(
      entries: [
        _oldEntry(id: 'last-year', createdAt: DateTime(2025, 5, 18)),
      ],
      now: DateTime(2026, 5, 18),
    );

    expect(cards.map((c) => c.entry.id), ['last-year']);

    final after = await service.stats();
    expect(after.resurfacedCount, before.resurfacedCount);
    expect(after.openedCount, before.openedCount);
  });

  test('selectByAnniversary returns empty for missing or unmatched entries',
      () async {
    final dir = await Directory.systemTemp.createTemp('vm_anniversary_empty');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));
    final now = DateTime(2026, 5, 18);

    expect(
      await service.selectByAnniversary(entries: const [], now: now),
      isEmpty,
    );
    expect(
      await service.selectByAnniversary(
        entries: [
          _oldEntry(id: 'unmatched', createdAt: DateTime(2025, 3, 12)),
        ],
        now: now,
      ),
      isEmpty,
    );
  });

  test('selectByAnniversary attaches belief relation only when genuinely related',
      () async {
    final dir = await Directory.systemTemp.createTemp('vm_anniversary_belief');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));
    final now = DateTime(2026, 5, 18);
    final cards = await service.selectByAnniversary(
      entries: [
        _oldEntry(
          id: 'related',
          createdAt: DateTime(2025, 5, 18),
          themes: const ['work'],
        ),
      ],
      currentBelief: 'You carry too much at work',
      now: now,
    );
    expect(cards, hasLength(1));
    expect(cards.first.beliefRelation, isNotEmpty);
  });

  test(
      'selectByAnniversary leaves belief relation empty when not genuinely related',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('vm_anniversary_no_belief');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = MemoryResurfacingService(MemoryResurfacingStore(prefs));
    final now = DateTime(2026, 5, 18);
    final cards = await service.selectByAnniversary(
      entries: [
        JournalEntry(
          id: 'unrelated',
          createdAt: DateTime(2025, 5, 18),
          transcript: 'I want to spend more time traveling abroad',
          durationSeconds: 40,
          reflection: const Reflection(
            mood: '',
            emotionalIntensity: 0,
            recurringThemes: ['travel'],
            exactLanguagePattern: 'time traveling abroad',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      ],
      currentBelief: 'You carry too much at work',
      now: now,
    );
    expect(cards, hasLength(1));
    expect(cards.first.beliefRelation, isEmpty);
  });
}
