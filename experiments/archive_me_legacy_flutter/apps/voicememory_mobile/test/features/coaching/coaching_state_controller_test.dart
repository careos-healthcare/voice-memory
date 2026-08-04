import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/coaching/controllers/coaching_state_controller.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services_providers.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  test('new journal entries trigger background coaching analysis', () async {
    final store = _FakeJournalStore();
    final container = ProviderContainer(
      overrides: [journalStoreProvider.overrideWithValue(store)],
    );
    final subscription = container.listen(
      coachingStateControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);

    final now = DateTime.now().toUtc();
    store.emit([
      _entry('one', now, 'Planning reduced my workload today.'),
      _entry(
        'two',
        now.subtract(const Duration(hours: 1)),
        'My workload felt clearer after planning.',
      ),
    ]);

    await _waitFor(
      () =>
          container.read(coachingStateControllerProvider).insight?.category ==
          'Recurring Pattern',
    );
    final state = container.read(coachingStateControllerProvider);
    expect(state.isAnalyzing, isFalse);
    expect(state.insight, isNotNull);
    expect(state.insight!.sourceEntryIds, containsAll(['one', 'two']));

    subscription.close();
    container.dispose();
    await store.close();
  });
}

class _FakeJournalStore extends JournalStore {
  _FakeJournalStore() : super(file: File('unused-coaching-test.json'));

  final StreamController<List<JournalEntry>> _controller =
      StreamController<List<JournalEntry>>.broadcast();
  List<JournalEntry> _entries = const [];

  @override
  Stream<List<JournalEntry>> watchAll() async* {
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Future<List<JournalEntry>> loadAll({bool includeDeleted = false}) async =>
      _entries
          .where((entry) => includeDeleted || !entry.isDeleted)
          .toList(growable: false);

  void emit(List<JournalEntry> entries) {
    _entries = List.unmodifiable(entries);
    _controller.add(_entries);
  }

  Future<void> close() => _controller.close();
}

JournalEntry _entry(String id, DateTime createdAt, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 12,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: ['workload'],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for coaching analysis.');
}
