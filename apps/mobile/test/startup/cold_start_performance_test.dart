import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/startup/cold_start_deferred_work.dart';
import 'package:archiveme_mobile/startup/heavy_worker_warmup.dart';
import 'package:archiveme_mobile/storage/recent_entry_snippet_cache.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 12,
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() {
    ColdStartDeferredWork.resetForTest();
    HeavyWorkerWarmup.resetForTest();
    RecentEntrySnippetCache.resetForTest();
  });

  test('hybrid search work stays queued until the interactive frame', () async {
    var ran = 0;
    ColdStartDeferredWork.defer(() async {
      ran += 1;
    });

    expect(ColdStartDeferredWork.pendingCount, 1);
    expect(ran, 0);

    await ColdStartDeferredWork.run();
    expect(ran, 1);
    expect(ColdStartDeferredWork.hasStarted, isTrue);

    await ColdStartDeferredWork.run();
    expect(ran, 1);
  });

  test(
    'worker warmup matches search, insights, and reflection routes only',
    () async {
      expect(HeavyWorkerWarmup.locationNeedsWorkers('/record'), isFalse);
      expect(
        HeavyWorkerWarmup.locationNeedsWorkers('/archive-belief'),
        isFalse,
      );
      expect(HeavyWorkerWarmup.locationNeedsWorkers('/explore'), isTrue);
      expect(HeavyWorkerWarmup.locationNeedsWorkers('/ask-archive'), isTrue);
      expect(HeavyWorkerWarmup.locationNeedsWorkers('/theories'), isTrue);
      expect(
        HeavyWorkerWarmup.locationNeedsWorkers('/pressure-insights'),
        isTrue,
      );

      await HeavyWorkerWarmup.warmForLocation('/record');
      expect(HeavyWorkerWarmup.didWarm, isFalse);

      await HeavyWorkerWarmup.warmForLocation('/explore');
      expect(HeavyWorkerWarmup.didWarm, isTrue);

      await HeavyWorkerWarmup.warmForLocation('/theories');
      expect(HeavyWorkerWarmup.didWarm, isTrue);
    },
  );

  test('snippet cache keeps the newest truncated moments for the feed', () {
    final long = 'word ' * 80;
    RecentEntrySnippetCache.instance.remember([
      _entry(
        id: 'older',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'older moment',
      ),
      _entry(
        id: 'newer',
        createdAt: DateTime.utc(2026, 9, 1),
        transcript: long,
      ),
    ]);

    expect(RecentEntrySnippetCache.instance.snippets.first.id, 'newer');
    expect(
      RecentEntrySnippetCache.instance.snippets.first.text.length,
      lessThanOrEqualTo(RecentEntrySnippetCache.maxChars + 1),
    );
    expect(
      RecentEntrySnippetCache.instance.snippets.first.text.endsWith('…'),
      isTrue,
    );

    final preview = RecentEntrySnippetCache.instance.previewEntries();
    final feed = ArchiveFeedState(
      loadState: ArchiveBeliefLoadState.loaded,
      entries: preview,
      totalCount: preview.length,
      archiveTotalCount: preview.length,
    );
    expect(feed.entries.first.id, 'newer');
    expect(feed.loadState, ArchiveBeliefLoadState.loaded);
  });
}
