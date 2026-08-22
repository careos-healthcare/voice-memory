import 'package:archiveme_mobile/features/sync/journal_pull_paginator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

Map<String, dynamic> _raw(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026),
  transcript: 't',
  durationSeconds: 1,
  reflection: _reflection(),
  updatedAt: DateTime.utc(2026, 1, 2),
  revision: 1,
  changeId: 'c-$id',
).toJson();

void main() {
  test('rejects cyclic cursor', () {
    final paginator = JournalPullPaginator(maxPages: 10);
    paginator.ingestPage(
      rawEntries: [_raw('a')],
      nextCursor: 'cursor-2',
    );
    paginator.ingestPage(
      rawEntries: [_raw('b')],
      nextCursor: 'cursor-3',
      currentCursor: 'cursor-2',
    );

    final cyclic = paginator.ingestPage(
      rawEntries: [_raw('c')],
      nextCursor: 'cursor-3',
      currentCursor: 'cursor-2',
    );
    expect(cyclic, isA<JournalPullPageAborted>());
    expect((cyclic as JournalPullPageAborted).reason, 'cyclic_cursor');
  });

  test('deduplicates repeated entry ids across pages', () {
    final paginator = JournalPullPaginator();
    paginator.ingestPage(rawEntries: [_raw('dup')], nextCursor: 'c2');
    final second =
        paginator.ingestPage(
              rawEntries: [_raw('dup'), _raw('unique')],
              currentCursor: 'c2',
            )
            as JournalPullPageAccepted;
    expect(second.entries.map((e) => e.id), ['unique']);
  });
}