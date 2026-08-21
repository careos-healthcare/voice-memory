import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Why a single attribute was refused by [ProofAnalyticsGuard].
enum AnalyticsDropReason {
  /// The exact key is on the forbidden list.
  forbiddenKey,

  /// The key contains a forbidden pattern (e.g. `topic_label`).
  forbiddenPattern,

  /// The key is structurally unknown, so it is refused by default.
  notAllowlisted,

  /// The key is allowed but the value was free text / out of shape.
  valueShape,

  /// The value was neither bool, num, nor String.
  valueType,

  /// The payload exceeded the maximum attribute count.
  payloadCap,

  /// The guard itself failed while evaluating the attribute.
  guardError,
}

/// A single refused attribute. Values are never retained — only the key,
/// the reason, and the value's runtime type — so drop records can never
/// themselves become a content leak.
@immutable
class AnalyticsGuardDrop {
  const AnalyticsGuardDrop({
    required this.event,
    required this.key,
    required this.reason,
    required this.valueType,
  });

  final String event;
  final String key;
  final AnalyticsDropReason reason;
  final String valueType;

  @override
  String toString() =>
      'AnalyticsGuardDrop($event, $key, ${reason.name}, $valueType)';
}

/// Fail-closed privacy guard for outbound analytics payloads.
///
/// Every attribute must clear three independent gates before it may be
/// emitted:
///
/// 1. It must not match a forbidden key rule (checked first, always wins).
/// 2. Its key must be on [allowedKeys] — unknown keys are refused, so new
///    content-bearing attributes cannot leak by simply not being listed yet.
/// 3. Its value must be structural: a bool, a finite num, or an id-shaped
///    string ([_idShape]). This is the gate that stops free text being
///    smuggled through an otherwise legitimate key.
///
/// The guard never throws: any internal failure drops the attribute.
class ProofAnalyticsGuard {
  ProofAnalyticsGuard._();

  /// Firebase itself caps event attributes; we cap lower and drop the rest.
  static const int maxAttributes = 25;

  /// The only value shape a string attribute may take.
  static final RegExp _idShape = RegExp(r'^[a-z0-9_]{1,40}$');

  /// Structural attribute keys that may be emitted.
  ///
  /// The baseline is `ActivationFunnelAnalytics.allowedPropertyKeys` (copied
  /// rather than imported so the guard has no dependency on feature code and
  /// cannot be widened by an edit elsewhere), plus the proof-admission
  /// structural keys.
  static const Set<String> allowedKeys = {
    // --- Activation funnel baseline -------------------------------------
    'entry_count',
    'has_connected_thread',
    'has_parent_entry',
    'has_real_timeline',
    'has_phrase',
    'has_confirmed_repeat',
    'has_custom_name',
    'has_free_text',
    'option_type',
    'answer',
    'comparison_state',
    'has_strong_evidence',
    'was_evidence',
    'has_snippets',
    'has_pattern_detail_cta',
    'milestone_count',
    'phrase_count',
    'relation_state',
    'source',
    'stage',
    'card_type',
    'reason',
    'plan',
    'ref',
    'method',
    'enabled',
    'error_type',
    'line_id',
    'relevance',
    'connection_mode',
    'memory_scope',
    'entry_memory_mode',
    'thread_scope',
    'score_band',
    'record_count',
    'authority_state',
    'influence_level',
    'reason_id',
    'filter_type',
    'result_count_bucket',
    'collection_count_bucket',
    'action_type',
    'format',
    'selection_count_bucket',
    'reliability_state',
    'pack_count_bucket',
    'decision_id',
    'current_intent',
    'relevance_band',
    'priority_band',
    'status',
    'action_item_count_bucket',
    'suggested_action',
    'entry_aboutness',
    'surfacing_mode',
    'surface_type',
    'preservation_source',
    'fact_type',
    'fact_count_bucket',
    'share_type',
    'prompt_type',
    'has_change',
    'has_helped',
    'has_watch_target',
    'days_since_set',
    'days_since_seen',
    'step',
    'answer_type',
    'lifecycle_state',
    // --- Structural keys used by existing non-funnel events -------------
    'surface',
    'kind',
    'cohort_day',
    'reflection_count',
    // --- Proof admission structural keys --------------------------------
    'admission_result',
    'rejection_reason',
    'confidence_band',
    'source_count_band',
    'contradiction_count_band',
    'correction_choice',
    'migration_version',
    'scorer_version',
    'verifier_version',
    'config_version',
    'eligibility_policy_version',
    'duration_band',
    // --- Beta analytics structural keys ---------------------------------
    'intent',
    'capture_kind',
    'review_outcome',
    'purpose',
    'decision',
    'result',
    'latency_bucket',
    'within_window',
    'policy_version',
    'scope',
    'reason_bucket',
  };

  /// Forbidden exact keys, in normalised form (lowercase, separators
  /// stripped) so `entry_id` and `entryId` both land on `entryid`.
  ///
  /// `score`, `path` and `key` are deliberately exact-only: as substrings
  /// they would also kill legitimate structural keys such as `score_band`
  /// and `scorer_version`, and anything else containing them is already
  /// refused by the allowlist gate.
  static const Set<String> forbiddenExactKeys = {
    'transcript',
    'transcripts',
    'quote',
    'quotes',
    'conclusion',
    'conclusions',
    'observation',
    'observations',
    'interpretation',
    'interpretations',
    'wording',
    'note',
    'notes',
    'prompt',
    'prompts',
    'question',
    'questions',
    'theme',
    'themes',
    'topic',
    'topics',
    'label',
    'labels',
    'title',
    'titles',
    'entryid',
    'archiveid',
    'proofid',
    'evidenceid',
    'fingerprint',
    'score',
    'scores',
    'rawscore',
    'path',
    'filepath',
    'filename',
    'stacktrace',
    'errormessage',
    'recovery',
    'key',
    'apikey',
    'secret',
    'token',
  };

  /// Forbidden key substrings, matched against the normalised key so that
  /// both `topic_label` and `topicLabel` are caught.
  ///
  /// Kept deliberately small and specific. Multi-word identifier patterns
  /// (`entryid`, `errormessage`, ...) are listed here rather than short
  /// generic words to keep the false-positive rate at zero against
  /// [allowedKeys].
  static const Set<String> forbiddenKeySubstrings = {
    'transcript',
    'quote',
    'conclusion',
    'observation',
    'interpretation',
    'wording',
    'note',
    'prompt',
    'question',
    'theme',
    'topic',
    'label',
    'title',
    'entryid',
    'archiveid',
    'proofid',
    'evidenceid',
    'fingerprint',
    'stacktrace',
    'errormessage',
    'filename',
    'filepath',
    'recovery',
    'secret',
    'token',
    'apikey',
  };

  /// Allowlisted keys that contain a forbidden substring but are known to
  /// be structural enums. They bypass [forbiddenKeySubstrings] only —
  /// [forbiddenExactKeys] still wins, and the value-shape gate still runs.
  static const Set<String> structuralExemptions = {'prompt_type'};

  static final List<AnalyticsGuardDrop> _drops = <AnalyticsGuardDrop>[];
  static int _droppedCount = 0;

  /// Every attribute refused so far, capped so long-running sessions cannot
  /// grow without bound. Use [droppedCount] for the true total.
  @visibleForTesting
  static List<AnalyticsGuardDrop> get drops => List.unmodifiable(_drops);

  /// Total attributes refused since the last [resetForTest].
  @visibleForTesting
  static int get droppedCount => _droppedCount;

  @visibleForTesting
  static void resetForTest() {
    _drops.clear();
    _droppedCount = 0;
  }

  /// Returns the subset of [parameters] that is safe to emit.
  ///
  /// Never throws, and never passes a refused value through in any form.
  static Map<String, Object> sanitize(
    String event,
    Map<String, Object>? parameters,
  ) {
    if (parameters == null || parameters.isEmpty) return const {};
    final safe = <String, Object>{};
    for (final entry in parameters.entries) {
      try {
        if (safe.length >= maxAttributes) {
          _record(
            event,
            entry.key,
            AnalyticsDropReason.payloadCap,
            entry.value,
          );
          continue;
        }
        final emitKey = _emitKey(entry.key);
        final matchKey = _matchKey(entry.key);
        if (emitKey.isEmpty || matchKey.isEmpty) {
          _record(
            event,
            entry.key,
            AnalyticsDropReason.notAllowlisted,
            entry.value,
          );
          continue;
        }

        // Gate 1 — forbidden rules, checked first and always winning.
        if (forbiddenExactKeys.contains(matchKey)) {
          _record(
            event,
            emitKey,
            AnalyticsDropReason.forbiddenKey,
            entry.value,
          );
          continue;
        }
        if (!structuralExemptions.contains(emitKey) &&
            _hasForbiddenSubstring(matchKey)) {
          _record(
            event,
            emitKey,
            AnalyticsDropReason.forbiddenPattern,
            entry.value,
          );
          continue;
        }

        // Gate 2 — unknown keys are refused by default.
        if (!allowedKeys.contains(emitKey)) {
          _record(
            event,
            emitKey,
            AnalyticsDropReason.notAllowlisted,
            entry.value,
          );
          continue;
        }

        // Gate 3 — the value must itself be structural.
        final value = entry.value;
        if (value is bool) {
          safe[emitKey] = value;
        } else if (value is num) {
          if (value is double && (value.isNaN || value.isInfinite)) {
            _record(event, emitKey, AnalyticsDropReason.valueShape, value);
          } else {
            safe[emitKey] = value;
          }
        } else if (value is String) {
          if (_idShape.hasMatch(value)) {
            safe[emitKey] = value;
          } else {
            _record(event, emitKey, AnalyticsDropReason.valueShape, value);
          }
        } else {
          _record(event, emitKey, AnalyticsDropReason.valueType, value);
        }
      } catch (_, stackTrace) {
        // Fail closed: an attribute we could not fully evaluate is dropped.
        _record(event, entry.key, AnalyticsDropReason.guardError, null);
      }
    }
    return safe;
  }

  static bool _hasForbiddenSubstring(String matchKey) {
    for (final pattern in forbiddenKeySubstrings) {
      if (matchKey.contains(pattern)) return true;
    }
    return false;
  }

  /// Key as it would be emitted: lowercase, non-id characters folded to `_`.
  static String _emitKey(String key) => key
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9_]'), '_')
      .replaceAll(RegExp('_+'), '_');

  /// Key reduced to letters and digits for rule matching, so `topic_label`,
  /// `topicLabel` and `Topic Label` all normalise to `topiclabel`.
  static String _matchKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  static void _record(
    String event,
    String key,
    AnalyticsDropReason reason,
    Object? value,
  ) {
    _droppedCount += 1;
    if (_drops.length < 200) {
      _drops.add(
        AnalyticsGuardDrop(
          event: event,
          key: key,
          reason: reason,
          valueType: value == null ? 'null' : value.runtimeType.toString(),
        ),
      );
    }
    if (kDebugMode) {
      AppLogger.debug('ProofAnalyticsGuard: dropped $event.$key (${reason.name})');
    }
  }
}