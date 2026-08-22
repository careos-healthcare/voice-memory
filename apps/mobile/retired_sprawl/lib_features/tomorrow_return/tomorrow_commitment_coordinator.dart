import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_reminder.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Creates, completes, and resolves tomorrow commitments.
abstract class TomorrowCommitmentCoordinator {
  TomorrowCommitmentCoordinator._();

  static TomorrowCommitmentStore _store() =>
      TomorrowCommitmentStore(AppServices.instance.prefs);

  static Future<TomorrowCommitment?> load({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.tomorrowCommitmentForPreview(clock);
    }
    return _store().read();
  }

  static Future<TomorrowCommitmentDisplayState> displayState({
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final commitment = await load(now: clock);
    if (commitment == null) return TomorrowCommitmentDisplayState.hidden;
    return commitment.displayState(clock);
  }

  static Future<TomorrowCommitment> saveFromReturnLoop(
    TomorrowReturnLoop loop, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final commitment = TomorrowCommitment(
      committedAt: clock,
      targetDate: TomorrowCommitment.tomorrowFrom(clock),
      promptText: _promptFromLoop(loop),
      watchForChips: loop.displayWatchChips,
    );
    await _store().write(commitment);
    await TomorrowCommitmentReminder.scheduleIfAvailable(commitment);
    return commitment;
  }

  static Future<void> markCompleteIfTargetDay({DateTime? now}) async {
    if (ScreenshotMode.enabled) return;
    final clock = now ?? DateTime.now();
    final store = _store();
    final existing = await store.read();
    if (existing == null || existing.completedAt != null) return;
    final today = TomorrowCommitment.dateOnly(clock);
    final target = TomorrowCommitment.dateOnly(existing.targetDate);
    if (today == target) {
      await store.write(existing.copyWith(completedAt: clock));
    }
  }

  static Future<void> acknowledgePatternsOpened({DateTime? now}) async {
    if (ScreenshotMode.enabled) return;
    final clock = now ?? DateTime.now();
    final store = _store();
    final existing = await store.read();
    if (existing == null) return;
    if (existing.displayState(clock) ==
        TomorrowCommitmentDisplayState.awaitingReturn) {
      await store.write(existing.copyWith(lastOpenedDate: clock));
    }
  }

  static String _promptFromLoop(TomorrowReturnLoop loop) {
    final prompt = loop.displayTomorrowPrompt.trim();
    if (prompt.isNotEmpty) return prompt;
    return ConsumerUiCopy.tomorrowCommitmentDefaultPrompt;
  }
}