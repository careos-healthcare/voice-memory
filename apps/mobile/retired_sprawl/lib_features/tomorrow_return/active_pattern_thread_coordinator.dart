import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Persists and loads the user's active pattern thread.
abstract class ActivePatternThreadCoordinator {
  ActivePatternThreadCoordinator._();

  static const _engine = ActivePatternThreadEngine();

  static ActivePatternThreadStore _store() =>
      ActivePatternThreadStore(AppServices.instance.prefs);

  static Future<ActivePatternThread?> loadCurrentThread() async {
    if (ScreenshotMode.enabled) {
      return screenshotSample();
    }
    return _store().readCurrent();
  }

  static ActivePatternThread screenshotSample() =>
      ScreenshotSampleData.activePatternThreadSample;

  /// Seeds the active thread after first-session accept (no watch-for check yet).
  static Future<void> writeCurrentForFirstSession(
    ActivePatternThread thread,
  ) async {
    if (ScreenshotMode.enabled) return;
    await _store().writeCurrent(thread);
  }

  static Future<ActivePatternThread> updateFromWatchForResult({
    required WatchForItem completed,
    String? momentSnippet,
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return screenshotSample();

    final clock = now ?? DateTime.now();
    final store = _store();
    final existing = await store.readCurrentIncludingPaused();
    final sameWatch =
        existing != null &&
        existing.watchForText.trim() == completed.text.trim();

    final thread = _engine.buildFromWatchForResult(
      completed: completed,
      existing: sameWatch ? existing : null,
      momentSnippet: momentSnippet,
      now: clock,
    );

    await store.writeCurrent(thread);
    if (_engine.shouldCompleteAsInactive(thread, now: clock)) {
      await completeThreadIfInactive(now: clock);
      return (await store.readCurrent()) ?? thread;
    }
    return thread;
  }

  static Future<void> pauseThread({DateTime? now}) async {
    if (ScreenshotMode.enabled) return;
    final store = _store();
    final current = await store.readCurrentIncludingPaused();
    if (current == null) return;
    final clock = now ?? DateTime.now();
    final paused = current.copyWith(
      status: ActivePatternThreadStatus.paused,
      updatedAt: clock,
    );
    await store.writeLatestInactive(paused);
    await store.writeCurrent(null);
    await store.appendHistory(paused);
  }

  static Future<ActivePatternThread?> resumeThread({DateTime? now}) async {
    if (ScreenshotMode.enabled) return screenshotSample();
    final store = _store();
    final inactive = await store.readLatestInactive();
    if (inactive == null ||
        inactive.status != ActivePatternThreadStatus.paused) {
      return store.readCurrent();
    }
    final clock = now ?? DateTime.now();
    final resumed = inactive.copyWith(
      status: ActivePatternThreadStatus.active,
      updatedAt: clock,
      nextPrompt: _engine.nextPromptFor(
        status: ActivePatternThreadStatus.active,
        watchForText: inactive.watchForText,
        needsOneMoreMoment: inactive.needsOneMoreMoment,
      ),
    );
    await store.writeCurrent(resumed);
    return resumed;
  }

  static Future<void> completeThreadIfInactive({DateTime? now}) async {
    if (ScreenshotMode.enabled) return;
    final store = _store();
    final current = await store.readCurrentIncludingPaused();
    if (current == null) return;
    if (!_engine.shouldCompleteAsInactive(current, now: now)) return;

    final clock = now ?? DateTime.now();
    final completed = current.copyWith(
      status: ActivePatternThreadStatus.paused,
      updatedAt: clock,
    );
    await store.writeLatestInactive(completed);
    await store.writeCurrent(null);
    await store.appendHistory(completed);
  }

  static String statusBadgeLabel(ActivePatternThread thread) {
    if (thread.needsOneMoreMoment) return 'Needs one more moment';
    switch (thread.status) {
      case ActivePatternThreadStatus.active:
        return 'Still active';
      case ActivePatternThreadStatus.easing:
        return 'May be easing';
      case ActivePatternThreadStatus.changing:
        return 'Changing shape';
      case ActivePatternThreadStatus.paused:
        return 'Paused';
    }
  }

  static String recordStatusLine(ActivePatternThread thread) {
    if (thread.needsOneMoreMoment) {
      return 'ArchiveMe needs one more moment on this pattern.';
    }
    switch (thread.status) {
      case ActivePatternThreadStatus.active:
        return 'It has shown up recently.';
      case ActivePatternThreadStatus.easing:
        return 'It may be easing.';
      case ActivePatternThreadStatus.changing:
        return 'It may be changing shape.';
      case ActivePatternThreadStatus.paused:
        return 'This pattern is paused.';
    }
  }

  static String lastCheckedSummary(ActivePatternThread thread) =>
      _engine.lastResultSummary(thread.lastResult);
}