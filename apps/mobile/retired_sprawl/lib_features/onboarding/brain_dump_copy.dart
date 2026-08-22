import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/lenses/career_transition_lens.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';
import 'package:archiveme_mobile/features/lenses/recovery_lens.dart';

/// Warm, low-pressure copy for the first-time brain dump onboarding capture.
abstract final class BrainDumpCopy {
  BrainDumpCopy._();

  static const title = 'Your first brain dump';
  static const subtitle =
      'Up to five minutes. Say whatever is loudest — no structure needed.';
  static const reassurance = 'Nothing you say here is wrong or too messy.';
  static const startCta = 'Start talking';
  static const finishCta = 'Finish when ready';
  static const timerLabel = 'Up to 5 minutes';
  static const connectingLabel = 'Getting the mic ready…';
  static const recordingLabel = 'Keep going — we are listening.';
  static const pausedLabel = 'Recording paused — your audio is saved securely.';
  static const generatingTitle = 'Generating your first insight…';

  /// Kept in step with `lib/features/onboarding/brain_dump_copy.dart`.
  ///
  /// `lib/features/onboarding` is a real directory, not one of the 373
  /// symlinks, so this file is an unreferenced duplicate that nothing compiles
  /// and the privacy scan never reads. It is corrected anyway: if the symlink
  /// generator ever points `lib/features/onboarding` here, the old sentence
  /// would come back *and* land inside the analyzer's excluded set.
  static const generatingBody =
      'Your recording was streamed to our server to be transcribed as you '
      'spoke. Now we are finding patterns in what you shared.';

  static const promptSeeds = [
    "What's the loudest thought in your head right now?",
    'What are you worried about this week?',
    'What keeps repeating in your mind lately?',
    'What would feel lighter if you said it out loud?',
    'What are you hoping changes soon?',
    'What do you wish someone understood about you today?',
  ];

  static List<String> promptSeedsFor(LifeStageLens? lens) {
    if (CareerTransitionLens.matches(lens)) {
      return CareerTransitionLens.coldStartPromptSeeds;
    }
    if (RecoveryLens.matches(lens)) {
      return RecoveryLens.coldStartPromptSeeds;
    }
    if (NewParentLens.matches(lens)) {
      return NewParentLens.coldStartPromptSeeds;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.coldStartPromptSeeds;
    }
    return promptSeeds;
  }

  static String titleFor(LifeStageLens? lens) {
    if (CareerTransitionLens.matches(lens)) {
      return CareerTransitionLens.coldStartTitle;
    }
    if (RecoveryLens.matches(lens)) {
      return RecoveryLens.coldStartTitle;
    }
    if (NewParentLens.matches(lens)) {
      return NewParentLens.coldStartTitle;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.coldStartTitle;
    }
    return title;
  }

  static String subtitleFor(LifeStageLens? lens) {
    if (CareerTransitionLens.matches(lens)) {
      return CareerTransitionLens.coldStartSubtitle;
    }
    if (RecoveryLens.matches(lens)) {
      return RecoveryLens.coldStartSubtitle;
    }
    if (NewParentLens.matches(lens)) {
      return NewParentLens.coldStartSubtitle;
    }
    if (GriefLossLens.matches(lens)) {
      return GriefLossLens.coldStartSubtitle;
    }
    return subtitle;
  }

  static String promptAt(int index, {LifeStageLens? lens}) {
    final seeds = promptSeedsFor(lens);
    return seeds[index % seeds.length];
  }

  static String promptAtDefault(int index) => promptAt(index);

  static String formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  static String formatRemaining(int elapsedSeconds, int maxSeconds) {
    final remaining = (maxSeconds - elapsedSeconds).clamp(0, maxSeconds);
    final minutes = remaining ~/ 60;
    final secs = remaining % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')} left';
  }
}