import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../models/journal_entry.dart';
import '../../models/reflection.dart';
import '../../services/app_services.dart';
import 'tomorrow_return_loop_models.dart';
import 'active_pattern_thread_coordinator.dart';
import '../activation/activation_tracker.dart';
import 'return_capture_store.dart';
import 'watch_for_engine.dart';
import 'watch_for_model.dart';
import 'watch_for_store.dart';

/// Orchestrates watch-for suggestions, acceptance, and next-day completion.
abstract class WatchForCoordinator {
  WatchForCoordinator._();

  static const _engine = WatchForEngine();

  static WatchForStore _store() => WatchForStore(AppServices.instance.prefs);

  static Future<WatchForItem?> loadPendingForToday({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.watchForPendingForToday(clock);
    }
    final pending = await _store().readPending();
    if (pending == null || !pending.isDueOn(clock)) return null;
    return pending;
  }

  static Future<WatchForItem?> loadLatestCompleted() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.watchForCompletedSample;
    }
    return _store().readLatestCompleted();
  }

  static WatchForItem buildSuggestedWatchForAfterSave({
    required List<JournalEntry> entries,
    TomorrowReturnLoop? loop,
    List<String> signals = const [],
    DateTime? now,
    int alternativeIndex = 0,
  }) {
    final clock = now ?? DateTime.now();
    final latest = entries.isEmpty
        ? null
        : ([
            ...entries,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).first;
    return _engine.buildSuggested(
      now: clock,
      loop: loop,
      signals: signals,
      latestEntry: latest,
      alternativeIndex: alternativeIndex,
    );
  }

  static Future<WatchForItem> acceptSuggestedWatchFor(WatchForItem item) async {
    if (ScreenshotMode.enabled) return item;
    final store = _store();
    await store.writePending(item);
    return item;
  }

  static Future<void> skipPendingForToday({DateTime? now}) async {
    if (ScreenshotMode.enabled) return;
    final clock = now ?? DateTime.now();
    final store = _store();
    final pending = await store.readPending();
    if (pending == null || !pending.isDueOn(clock)) return;
    final skipped = pending.copyWith(
      status: WatchForStatus.skipped,
      completedAt: clock,
    );
    await store.writePending(null);
    await store.writeLatestCompleted(skipped);
    await store.appendHistory(skipped);
    await ReturnCaptureStore.instance().clear();
    await ActivationTracker.trackReturnCaptureSkipped();
  }

  /// When the user records on the watch-for target day, compare and complete.
  static Future<WatchForItem?> completePendingAfterSave({
    required List<JournalEntry> entries,
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    if (entries.isEmpty) return null;

    final clock = now ?? DateTime.now();
    final store = _store();
    final pending = await store.readPending();
    if (pending == null || !pending.isDueOn(clock)) return null;

    final latest = ([
      ...entries,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).first;
    final captureStore = ReturnCaptureStore.instance();
    final selection = await captureStore.loadLatest();
    final comparisonHint =
        selection != null && selection.watchForId == pending.id
        ? selection.comparisonHint
        : null;
    final result = _engine.compareReflection(
      pending: pending,
      entry: latest,
      comparisonHint: comparisonHint,
    );
    final completed = pending.copyWith(
      status: WatchForStatus.checked,
      result: result,
      completedAt: clock,
      comparisonHint: comparisonHint,
    );

    await store.writePending(null);
    await store.writeLatestCompleted(completed);
    await store.appendHistory(completed);
    await captureStore.clear();
    if (comparisonHint != null) {
      await ActivationTracker.trackReturnCaptureRecordedAfterSelection();
    }
    await ActivationTracker.trackReturnedNextDayOnce();

    final moment = latest.reflection.concreteObservation.trim().isNotEmpty
        ? latest.reflection.concreteObservation.trim()
        : latest.transcript.trim();
    await ActivePatternThreadCoordinator.updateFromWatchForResult(
      completed: completed,
      momentSnippet: moment,
      now: clock,
    );

    return completed;
  }

  static String headlineFor(WatchForItem completed) => _engine.resultHeadline(
    completed.result,
    comparisonHint: completed.comparisonHint,
  );

  /// Body copy when only [WatchForItem.comparisonHint] is available (no entry).
  static String bodyForCompletedItem(WatchForItem completed) {
    final pendingShape = completed.copyWith(
      status: WatchForStatus.pending,
      result: WatchForResult.none,
    );
    return _engine.resultBody(
      pending: pendingShape,
      result: completed.result,
      entry: _blankEntry(),
      comparisonHint: completed.comparisonHint,
    );
  }

  static JournalEntry _blankEntry() => JournalEntry(
    id: 'watch_for_body_placeholder',
    createdAt: DateTime(2000),
    transcript: '',
    durationSeconds: 0,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 1,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );

  static String bodyFor({
    required WatchForItem completed,
    required JournalEntry entry,
  }) {
    final pendingShape = completed.copyWith(
      status: WatchForStatus.pending,
      result: WatchForResult.none,
    );
    return _engine.resultBody(
      pending: pendingShape,
      result: completed.result,
      entry: entry,
      comparisonHint: completed.comparisonHint,
    );
  }

  static String footerLineFor(WatchForResult result) {
    switch (result) {
      case WatchForResult.showedAgain:
      case WatchForResult.changedShape:
        return 'That gives tomorrow something clearer to compare.';
      case WatchForResult.didNotShow:
        return 'Tomorrow you can watch for whether it returns.';
      case WatchForResult.unclear:
        return 'One more moment tomorrow can make this clearer.';
      default:
        return '';
    }
  }
}
