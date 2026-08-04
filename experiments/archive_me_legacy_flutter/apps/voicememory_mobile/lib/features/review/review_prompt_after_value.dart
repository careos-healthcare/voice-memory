import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../referral/referral_invite_after_value.dart';

/// App Store Review Prompt After Value — one calm, dismissible rating ask
/// shown only after ArchiveMe has demonstrably shown value this session.
///
/// Guardrails by construction:
/// - Never on first launch, never before the second entry, never before a
///   real value moment, at most once per session, and at most once ever
///   (persisted asked flag).
/// - Suppressed for the session after a "Not quite" feedback response.
/// - Never triggered by a purchase completion — a value moment is the
///   only path in.
/// - All copy is compile-time constant; nothing from the archive can
///   appear in the prompt or its analytics.
abstract class ReviewPromptAfterValue {
  ReviewPromptAfterValue._();

  static const String title = 'Is ArchiveMe worth a quick rating?';
  static const String body =
      'If it helped you notice something useful, a rating would help others '
      'find it.';
  static const String ctaLabel = 'Rate ArchiveMe';
  static const String dismissLabel = 'Not now';

  /// The only source ids a review prompt event can carry.
  static const Set<String> stableSources = {
    'weekly_review',
    'thread_return',
    'belief_distance',
    'proof_counter',
    'pro_retention_yes',
    'referral_invite_copied',
  };

  // --- Session state ---

  /// Set when the card renders; at most one appearance per session.
  static bool shownThisSession = false;

  /// Set when the user closes the card; hides it for the session.
  static bool dismissedThisSession = false;

  static String? _usefulYesSource;
  static bool _notQuiteThisSession = false;
  static bool _proRetentionYes = false;
  static bool _inviteCopied = false;

  static final _Revision _revision = _Revision();

  /// Notifies when session value signals change, so an already-built
  /// surface can re-evaluate (e.g. show the prompt right after a
  /// useful-yes lands).
  static Listenable get changes => _revision;

  /// Called by the value-card feedback row. A useful-yes becomes a trigger
  /// source; a "Not quite" suppresses the prompt for the session.
  static void recordValueFeedback({
    required String cardType,
    required bool useful,
  }) {
    if (useful) {
      _usefulYesSource ??= ReferralInviteAfterValue.sourceForFeedbackCardType(
        cardType,
      );
    } else {
      _notQuiteThisSession = true;
    }
    _revision.bump();
  }

  /// Called when a Pro user answers Yes on the Pro retention check.
  static void recordProRetentionYes() {
    _proRetentionYes = true;
    _revision.bump();
  }

  /// Called when the user copies a referral invite — sharing the app is
  /// itself a strong value signal.
  static void recordReferralInviteCopied() {
    _inviteCopied = true;
    _revision.bump();
  }

  /// The stable source id of the strongest current value moment, or null
  /// when none exists yet. Explicit user signals win over passive ones.
  /// The passive weekly-review trigger additionally requires 3+ entries.
  static String? sourceFor({
    required int entryCount,
    required bool hasWeeklyReview,
  }) {
    if (entryCount < 2) return null;
    if (_usefulYesSource != null) return _usefulYesSource;
    if (_proRetentionYes) return 'pro_retention_yes';
    if (_inviteCopied) return 'referral_invite_copied';
    if (hasWeeklyReview && entryCount >= 3) return 'weekly_review';
    return null;
  }

  static bool shouldShow({
    required int entryCount,
    required bool hasWeeklyReview,
    required bool alreadyAsked,
  }) =>
      !alreadyAsked &&
      !shownThisSession &&
      !dismissedThisSession &&
      !_notQuiteThisSession &&
      sourceFor(entryCount: entryCount, hasWeeklyReview: hasWeeklyReview) !=
          null;

  @visibleForTesting
  static void resetSessionForTest() {
    shownThisSession = false;
    dismissedThisSession = false;
    _usefulYesSource = null;
    _notQuiteThisSession = false;
    _proRetentionYes = false;
    _inviteCopied = false;
  }
}

class _Revision extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Abstraction over the native in-app review API. No in-app review
/// dependency exists in this project yet, so the default is a safe no-op;
/// when a native dependency is added it plugs in here without touching
/// the prompt logic. Tests inject a fake.
abstract class ReviewLauncher {
  /// Requests the native in-app review flow. Returns true when a request
  /// was actually made to the platform.
  Future<bool> requestReview();
}

/// Safe default until a native in-app review dependency is wired up.
/// Never throws, never blocks, never opens anything.
class NoopReviewLauncher implements ReviewLauncher {
  const NoopReviewLauncher();

  @override
  Future<bool> requestReview() async => false;
}

/// Local persistence for the asked-once flag. Stores a single boolean —
/// no timestamps, counts, or content.
class ReviewPromptStore {
  ReviewPromptStore({this._prefs});

  final MobilePrefsStore? _prefs;

  static const String prefsKey = 'review_prompt';

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  /// True when the review prompt has ever been shown or requested.
  Future<bool> asked() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return false;
    try {
      final data = await prefs.readMap(prefsKey);
      return data?['asked'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Persists that the prompt was shown — it never appears again.
  Future<void> markAsked() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(prefsKey, {'asked': true});
    } catch (_) {
      // Persistence must never break the surface that hosts the prompt.
    }
  }
}
