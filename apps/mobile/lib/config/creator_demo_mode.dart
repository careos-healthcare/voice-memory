import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show ScreenshotMode, TrialMode;
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/foundation.dart';

/// Creator Demo Mode — internal/demo-only. Compile with
/// `--dart-define=ARCHIVEME_CREATOR_DEMO_MODE=true` to record safe App
/// Store / TikTok / demo videos.
///
/// Separate from [TrialMode] (participant trials) and [ScreenshotMode]
/// (static marketing captures).
///
/// Guardrails by construction:
/// - Disabled by default; only the explicit dart define can enable it in
///   a real build. There is no runtime toggle, setting, or URL that can
///   turn it on in production.
/// - When active, the real local archive stores are never read and never
///   written — demo entries exist only in code and cannot leak into (or
///   out of) a real user archive.
/// - Cloud sync is skipped entirely and production analytics events are
///   not sent.
/// - All demo copy is a compile-time constant, work-decision themed only:
///   no health, trauma, relationships, names, finances, or private
///   details, and no real user ids.
abstract class CreatorDemoMode {
  CreatorDemoMode._();

  /// Compile-time gate — false unless the dart define is explicitly true.
  static const bool enabled = bool.fromEnvironment(
    'ARCHIVEME_CREATOR_DEMO_MODE',
  );

  /// Test-only override so suites can exercise demo behavior without a
  /// dart define. Never set outside tests; [enabled] stays the only
  /// production path in.
  @visibleForTesting
  static bool debugForceEnabledForTest = false;

  /// True when demo behavior is active.
  static bool get isActive => enabled || debugForceEnabledForTest;

  // --- Safe demo content (compile-time only) ---

  /// The safe demo transcript lines used across demo entries.
  static const String demoLineFirstRecording =
      'I keep coming back to the same work decision.';
  static const String demoLineReturnedThought =
      'I noticed this thought returned again.';
  static const String demoLineWeeklyReview =
      'This week, one thread came back and one felt quieter.';
  static const String demoLineShareCard =
      'My archive noticed something I keep returning to.';

  /// Demo check-in records, crafted to walk the full value journey on the
  /// insights screen: thread return evidence, weekly review, belief
  /// distance, the share card, and the paywall bridge. Two threads: a
  /// "work decision" thread that keeps returning this week, and an older
  /// "evening wind-down" thread that has gone quieter.
  static List<PressureCheckInRecord> demoCheckIns({DateTime? now}) {
    final base = now ?? DateTime.now();
    PressureCheckInRecord record({
      required String id,
      required int daysAgo,
      required List<String> contextIds,
      String? fear,
      String transcript = '',
    }) {
      return PressureCheckInRecord(
        entryId: 'creator_demo_$id',
        createdAt: base.subtract(Duration(days: daysAgo)),
        optionId: 'could_not_stop',
        contextIds: contextIds,
        fear: fear,
        transcript: transcript,
      );
    }

    return [
      // Older evening thread — quieter this week.
      record(
        id: 'evening_1',
        daysAgo: 13,
        contextIds: const ['evening'],
        fear: 'Evening wind-down kept slipping late',
      ),
      record(
        id: 'evening_2',
        daysAgo: 9,
        contextIds: const ['evening'],
        fear: 'Evening wind-down slipping late again',
      ),
      // Work-decision thread — keeps returning this week.
      record(
        id: 'work_1',
        daysAgo: 6,
        contextIds: const ['work'],
        fear: 'I keep circling the same work decision',
        transcript: demoLineFirstRecording,
      ),
      record(
        id: 'work_2',
        daysAgo: 3,
        contextIds: const ['work'],
        fear: 'The same work decision came back today',
        transcript: demoLineReturnedThought,
      ),
      record(
        id: 'work_3',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: 'Circling the same work decision tonight',
        transcript: demoLineWeeklyReview,
      ),
    ];
  }

  /// Demo journal entries shown wherever the recording archive renders.
  /// Same safe work-decision theme; local-only, no audio paths.
  static List<JournalEntry> demoJournalEntries({DateTime? now}) {
    final base = now ?? DateTime.now();
    const reflection = Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work decision'],
      exactLanguagePattern: 'I keep coming back',
      concreteObservation:
          'The same work decision showed up again in this recording.',
      repeatedSignal: 'work decision',
    );
    JournalEntry entry({
      required String id,
      required int daysAgo,
      required String transcript,
    }) {
      return JournalEntry(
        id: 'creator_demo_$id',
        createdAt: base.subtract(Duration(days: daysAgo)),
        transcript: transcript,
        durationSeconds: 18,
        reflection: reflection,
      );
    }

    return [
      entry(id: 'j1', daysAgo: 6, transcript: demoLineFirstRecording),
      entry(id: 'j2', daysAgo: 3, transcript: demoLineReturnedThought),
      entry(id: 'j3', daysAgo: 0, transcript: demoLineWeeklyReview),
    ];
  }
}