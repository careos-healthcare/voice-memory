import 'dart:async';

import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_capture_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Creates and completes locked tomorrow check-ins.
abstract class TomorrowCheckInCoordinator {
  TomorrowCheckInCoordinator._();

  static const _defaultPrompt =
      'Tomorrow, check whether this pattern shows up again.';
  static const _defaultQuestion = 'Did this pattern show up again?';

  static TomorrowCheckInStore _store() =>
      TomorrowCheckInStore(AppServices.instance.prefs);

  static Future<TomorrowCheckIn> createForTomorrow({
    required String patternTitle,
    required String specificPrompt,
    String? checkInQuestion,
    String? sourceWatchForId,
    String? sourcePatternThreadId,
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.tomorrowCheckInDueSample;
    }
    final clock = now ?? DateTime.now();
    final tomorrow = WatchForItem.dateOnly(clock).add(const Duration(days: 1));
    final question = (checkInQuestion ?? '').trim().isNotEmpty
        ? checkInQuestion!.trim()
        : _defaultQuestion;
    final checkIn = TomorrowCheckIn(
      id: 'tci_${clock.microsecondsSinceEpoch}',
      createdAt: clock,
      targetDate: tomorrowCheckInDateKey(tomorrow),
      patternTitle: patternTitle.trim(),
      prompt: _defaultPrompt,
      question: question,
      options: kDefaultTomorrowCheckInOptions,
      sourceWatchForId: sourceWatchForId,
      sourcePatternThreadId: sourcePatternThreadId,
    );
    await _store().save(checkIn);
    await ActivationTracker.trackTomorrowCheckInCreated();
    unawaited(CheckInReminderService.maybeScheduleForCheckIn(checkIn));
    return checkIn;
  }

  static Future<TomorrowCheckIn> createFromWatchFor(
    WatchForItem watch, {
    String? sourcePatternThreadId,
    DateTime? now,
  }) {
    return createForTomorrow(
      patternTitle: watch.patternTitle ?? watch.displayShortPrompt,
      specificPrompt: watch.displaySpecificPrompt,
      checkInQuestion: watch.checkInQuestion,
      sourceWatchForId: watch.id,
      sourcePatternThreadId: sourcePatternThreadId,
      now: now,
    );
  }

  static Future<TomorrowCheckIn?> loadDueToday({DateTime? now}) async {
    if (ScreenshotMode.enabled && ScreenshotMode.recordCheckInDuePreview) {
      return ScreenshotSampleData.tomorrowCheckInDueSample;
    }
    final clock = now ?? DateTime.now();
    await _markMissedIfOverdue(clock);
    final due = await _store().loadDueToday(now: clock);
    if (due != null) {
      await ActivationTracker.trackTomorrowCheckInDueShown();
    }
    return due;
  }

  static Future<TomorrowCheckIn?> loadRecentlyCompleted() async {
    if (ScreenshotMode.enabled) return null;
    return _store().loadRecentlyCompleted();
  }

  /// Most recent missed check-in that still needs a "what got in the way?" prompt.
  static Future<TomorrowCheckIn?> loadMissedNeedingReason({
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    final missed = await _store().loadRecentMissed(now: now);
    if (missed == null) return null;
    final shown = await HookDiagnosisStore.instance()
        .wasMissedReasonPromptShown(missed.id);
    if (shown) return null;
    return missed;
  }

  static Future<TomorrowCheckIn?> loadRecentMissed({DateTime? now}) async {
    if (ScreenshotMode.enabled) return null;
    return _store().loadRecentMissed(now: now);
  }

  static Future<TomorrowCheckIn?> loadActive() async {
    if (ScreenshotMode.enabled) return null;
    return _store().loadActive();
  }

  static Future<bool> hasDueToday({DateTime? now}) async {
    final due = await loadDueToday(now: now);
    return due != null;
  }

  static Future<TomorrowCheckIn?> selectOption({
    required String checkInId,
    required String optionId,
  }) async {
    if (ScreenshotMode.enabled) {
      final sample = ScreenshotSampleData.tomorrowCheckInDueSample;
      return sample.copyWith(selectedOptionId: optionId);
    }
    final updated = await _store().selectOption(
      checkInId: checkInId,
      optionId: optionId,
    );
    if (updated == null) return null;
    final option = updated.selectedOption;
    if (option != null) {
      await ReturnCaptureStore.instance().saveSelection(
        ReturnCaptureSelection(
          watchForId: updated.id,
          selectedQuickAnswerId: option.id,
          comparisonHint: option.comparisonHint,
          createdAt: DateTime.now(),
        ),
      );
    }
    await ActivationTracker.trackTomorrowCheckInOptionSelected();
    return updated;
  }

  static Future<TomorrowCheckIn?> completeAfterSave({
    List<JournalEntry>? entries,
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return null;
    final active = await _store().loadActive();
    if (active == null || active.selectedOptionId == null) return null;
    final clock = now ?? DateTime.now();
    final today = tomorrowCheckInDateKey(clock);
    if (active.targetDate != today) return null;
    final completed = await _store().markCompleted(active.id, now: clock);
    if (completed != null) {
      await ReturnCaptureStore.instance().clear();
      await ActivationTracker.trackTomorrowCheckInCompleted();
      unawaited(CheckInReminderService.cancelCheckInReminder(active.id));
      await PatternMemoryCoordinator.recordCheckInCompletion(
        completed: completed,
        reflectionText: _latestReflectionText(entries),
        now: clock,
      );
    }
    return completed;
  }

  static String _latestReflectionText(List<JournalEntry>? entries) {
    if (entries == null || entries.isEmpty) return '';
    var latest = entries.first;
    for (final e in entries) {
      if (e.createdAt.isAfter(latest.createdAt)) latest = e;
    }
    return latest.transcript;
  }

  static Future<void> _markMissedIfOverdue(DateTime now) async {
    final active = await _store().loadActive();
    if (active == null || active.isCompleted) return;
    final today = tomorrowCheckInDateKey(now);
    if (active.targetDate.compareTo(today) >= 0) return;
    await _store().archiveOverdue(active);
    await ActivationTracker.trackTomorrowCheckInMissed();
  }
}