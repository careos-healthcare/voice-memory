import '../../product/consumer_ui_copy.dart';
import 'personal_return_prompt_model.dart';
import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_personal_evidence_summary_engine.dart';

/// Builds Record-screen starter prompts from the user's own local evidence.
///
/// Pure and deterministic. Prompts only ever reference what the user actually
/// logged — repeated terms, contexts, and the last pressure option — and ask
/// edge questions built for self-recognition: proving enough, fear of
/// stopping, avoiding feeling behind, continuing after it stopped helping,
/// and what an honest archive would notice. Never asserting ("you always"),
/// never shaming. With no evidence it falls back to the generic prompts.
class PersonalReturnPromptEngine {
  const PersonalReturnPromptEngine();

  static const _evidenceEngine = PressurePersonalEvidenceSummaryEngine();

  /// Shown at most this many prompts.
  static const int maxPrompts = 4;

  static const String _genericFallbackLine =
      'Start with whatever happened today — one honest sentence is enough.';

  static const String _smallMomentPrompt =
      'What did the pressure make you do today, even something small?';

  /// Honest-archive closer — the strongest self-recognition frame.
  static const String _archiveNoticePrompt =
      'What would you not want your archive to notice about today?';

  PersonalReturnPromptSet build(List<PressureCheckInRecord> records) {
    if (records.isEmpty) {
      return const PersonalReturnPromptSet(
        prompts: ConsumerUiCopy.recordStarterPrompts,
        personalized: false,
        emptyStateFallback: _genericFallbackLine,
      );
    }

    if (records.length >= 3) {
      final summary = _evidenceEngine.build(records);
      if (summary.hasSummary && summary.evidenceTerms.isNotEmpty) {
        return _evidenceBased(records, summary.evidenceTerms);
      }
    }

    // 1–2 entries, or 3+ without repeated evidence: gentle continuation.
    return _gentleContinuation(records);
  }

  /// Prompts built from repeated terms across 3+ entries.
  PersonalReturnPromptSet _evidenceBased(
    List<PressureCheckInRecord> records,
    List<String> terms,
  ) {
    final prompts = <String>[
      'What did ${terms.first} pressure make you rush or hide today?',
      if (terms.length >= 2)
        'What did ${terms[1]} pressure make you overdo today?',
    ];

    final optionLine = _optionLine(_latestOption(records));
    if (optionLine != null) prompts.add(optionLine);

    prompts.add(_archiveNoticePrompt);

    return PersonalReturnPromptSet(
      prompts: _capped(prompts),
      personalized: true,
      sourceTerms: terms,
    );
  }

  /// 1–2 entries: continue from the last logged moment — sharper questions,
  /// still gentle.
  PersonalReturnPromptSet _gentleContinuation(
    List<PressureCheckInRecord> records,
  ) {
    final prompts = <String>[];
    final sourceTerms = <String>[];

    final option = _latestOption(records);
    final optionLine = _optionLine(option);
    if (optionLine != null) {
      prompts.add(optionLine);
      sourceTerms.add(_optionTerm(option)!);
    } else {
      prompts.add(
        'You logged a pressure moment before. '
        'What did that pressure make you do today?',
      );
    }

    final contextLine = _repeatedContextLine(records, requireRepeat: false);
    if (contextLine != null) {
      prompts.add(contextLine);
      sourceTerms.add(_latestContextLabel(records)!);
    }

    prompts
      ..add('What did you avoid admitting today?')
      ..add(_smallMomentPrompt);

    return PersonalReturnPromptSet(
      prompts: _capped(prompts),
      personalized: true,
      sourceTerms: sourceTerms,
    );
  }

  List<String> _capped(List<String> prompts) {
    final seen = <String>{};
    final unique = [
      for (final p in prompts)
        if (seen.add(p)) p,
    ];
    if (unique.length < 3) unique.add(_smallMomentPrompt);
    return unique.take(maxPrompts).toList();
  }

  PressureCheckInOption? _latestOption(List<PressureCheckInRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.option;
  }

  /// Edge line for the last logged option — built for self-recognition,
  /// never asserting, never shaming.
  String? _optionLine(PressureCheckInOption? option) {
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'Where did stopping feel unsafe today?';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'What did you do today mainly to avoid feeling behind?';
      case PressureCheckInOption.hadToProveEnough:
        return 'What did you do today to prove you were enough?';
      case PressureCheckInOption.guiltyResting:
        return 'What rest did you talk yourself out of today?';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'What did you keep doing after it stopped helping?';
      case null:
        return null;
    }
  }

  String? _optionTerm(PressureCheckInOption? option) {
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'stopping';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'feeling behind';
      case PressureCheckInOption.hadToProveEnough:
        return 'proving yourself';
      case PressureCheckInOption.guiltyResting:
        return 'guilt about resting';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'needing to feel productive';
      case null:
        return null;
    }
  }

  /// "What did evening pressure make you overdo today?"
  /// With [requireRepeat], the context must appear in 2+ entries.
  String? _repeatedContextLine(
    List<PressureCheckInRecord> records, {
    bool requireRepeat = true,
  }) {
    final label = requireRepeat
        ? _topRepeatedContextLabel(records)
        : _latestContextLabel(records);
    if (label == null) return null;
    return 'What did $label pressure make you overdo today?';
  }

  String? _latestContextLabel(List<PressureCheckInRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final record in sorted) {
      final contexts = record.contexts;
      if (contexts.isNotEmpty) return contexts.first.label.toLowerCase();
    }
    return null;
  }

  String? _topRepeatedContextLabel(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        final label = context.label.toLowerCase();
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    String? best;
    var bestCount = 1; // require >= 2 to call it repeated.
    final labels = counts.keys.toList()..sort();
    for (final label in labels) {
      final count = counts[label]!;
      if (count > bestCount) {
        bestCount = count;
        best = label;
      }
    }
    return best;
  }
}
