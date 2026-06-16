import 'package:flutter/foundation.dart';

import '../memory/memory_scope_policy.dart';

/// User-Approved Archive Belief Share Card — a privacy-safe,
/// screenshot-worthy "My archive noticed…" card the user explicitly
/// approves before anything is copied or shared.
///
/// Guardrails by construction:
/// - Every line on the card is a compile-time constant chosen from a
///   short generalized list. No raw notes, transcripts, snippets, belief
///   phrases, source terms, names, emails, counts, dates, or entry ids
///   have a path into the card or the copied text.
/// - No free-text editing: the repo has no safe validator for emails,
///   phone numbers, URLs, or names, so the card uses selectable
///   generalized lines only.
/// - Nothing is shared automatically. The user picks a line, then taps
///   Copy (or the system share sheet). There is no feed and no reward.
/// - Appears only after a real value moment this session, at most once
///   per session, and not after a "Not quite" feedback response.
abstract class ArchiveBeliefShareCard {
  ArchiveBeliefShareCard._();

  static const String title = 'My ArchiveMe card';
  static const String pickerPrompt = 'Choose the line for your card.';
  static const String footer = 'Recorded privately with ArchiveMe';
  static const String privacyLine = 'No recordings or notes are shared.';
  static const String copyCtaLabel = 'Copy card text';
  static const String shareCtaLabel = 'Share';
  static const String dismissLabel = 'Not now';
  static const String copiedConfirmation = 'Card text copied.';

  /// Stable analytics card type for every event this card emits.
  static const String cardType = 'archive_belief_share';

  /// The only lines that can ever appear on the card — generalized,
  /// hedged ("noticed", "may be"), and free of any archive content.
  static const List<ArchiveBeliefShareLine> lines = [
    ArchiveBeliefShareLine(
      id: 'returning_to',
      text: 'My archive noticed something I keep returning to.',
    ),
    ArchiveBeliefShareLine(
      id: 'unnamed_pattern',
      text: 'My archive noticed a pattern I had not named yet.',
    ),
    ArchiveBeliefShareLine(
      id: 'came_back',
      text: 'My archive noticed something that keeps coming back.',
    ),
    ArchiveBeliefShareLine(
      id: 'may_be_changing',
      text: 'My archive noticed that something may be changing.',
    ),
    ArchiveBeliefShareLine(
      id: 'returned_faded_changed',
      text: 'My archive helped me compare what returned, faded, or changed.',
    ),
  ];

  /// The only line ids that can ever appear in analytics.
  static const Set<String> stableLineIds = {
    'returning_to',
    'unnamed_pattern',
    'came_back',
    'may_be_changing',
    'returned_faded_changed',
  };

  /// Resolves a line by id; unknown ids return null — there is no
  /// fallback that could surface unexpected text.
  static ArchiveBeliefShareLine? lineFor(String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  /// The exact text written to the clipboard or the share sheet for a
  /// selected line. Built only from compile-time constants.
  static String copiedTextFor(String lineId) {
    final line = lineFor(lineId);
    if (line == null) return '';
    return '${line.text}  $footer. $privacyLine';
  }

  // --- Trigger state (session only) ---

  /// The only value-moment source ids that can make the card eligible.
  static const Set<String> stableSources = {
    'belief_distance',
    'weekly_review',
    'thread_return',
    'proof_counter',
  };

  /// Set when the card renders; at most one appearance per session.
  static bool shownThisSession = false;

  /// Set when the user taps "Not now"; hides the card for the session.
  static bool dismissedThisSession = false;

  static String? _usefulYesSource;
  static bool _notQuiteThisSession = false;

  static final _Revision _revision = _Revision();

  /// Notifies when session value signals change, so an already-built
  /// surface can re-evaluate (e.g. show the card right after a
  /// useful-yes lands).
  static Listenable get changes => _revision;

  /// Called by the value-card feedback row. A useful-yes becomes a
  /// trigger source; a "Not quite" suppresses the card for the session.
  static void recordValueFeedback({
    required String cardType,
    required bool useful,
  }) {
    if (useful) {
      _usefulYesSource ??= sourceForFeedbackCardType(cardType);
    } else {
      _notQuiteThisSession = true;
    }
    _revision.bump();
  }

  /// Maps a feedback-row card type to this card's stable source id;
  /// unknown card types never become a trigger.
  static String? sourceForFeedbackCardType(String cardType) {
    switch (cardType) {
      case 'weekly_thread_review':
        return 'weekly_review';
      case 'thread_return_evidence':
        return 'thread_return';
      case 'belief_distance':
        return 'belief_distance';
      case 'archive_proof_counter':
        return 'proof_counter';
    }
    return null;
  }

  /// The stable source id of the strongest current value moment, or null
  /// when none exists yet. An explicit useful-yes wins over passive
  /// surfaces.
  static String? sourceFor({
    required bool hasBeliefDistance,
    required bool hasWeeklyReview,
    required bool hasThreadReturn,
  }) {
    if (_usefulYesSource != null) return _usefulYesSource;
    if (hasBeliefDistance) return 'belief_distance';
    if (hasWeeklyReview) return 'weekly_review';
    if (hasThreadReturn) return 'thread_return';
    return null;
  }

  /// True only after a real value moment, at most once per session, and
  /// not after a "Not quite" this session.
  static bool shouldShow({
    required bool hasBeliefDistance,
    required bool hasWeeklyReview,
    required bool hasThreadReturn,
  }) =>
      // Memory off: the share prompt rides on memory-based value moments,
      // so it never appears while connections are paused.
      MemoryScopePolicy.memoryClaimsAllowed &&
      !shownThisSession &&
      !dismissedThisSession &&
      !_notQuiteThisSession &&
      sourceFor(
            hasBeliefDistance: hasBeliefDistance,
            hasWeeklyReview: hasWeeklyReview,
            hasThreadReturn: hasThreadReturn,
          ) !=
          null;

  @visibleForTesting
  static void resetSessionForTest() {
    shownThisSession = false;
    dismissedThisSession = false;
    _usefulYesSource = null;
    _notQuiteThisSession = false;
  }
}

/// One selectable generalized line: a stable analytics id plus the
/// compile-time text it renders and copies.
class ArchiveBeliefShareLine {
  const ArchiveBeliefShareLine({required this.id, required this.text});

  final String id;
  final String text;
}

class _Revision extends ChangeNotifier {
  void bump() => notifyListeners();
}
