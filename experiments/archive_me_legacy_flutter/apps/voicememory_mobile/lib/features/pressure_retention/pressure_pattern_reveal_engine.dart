import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_context.dart';
import 'pressure_evidence_confidence.dart';
import 'pressure_pattern_reveal_model.dart';

/// Builds a [PressurePatternReveal] from local pressure check-in records.
///
/// Pure and deterministic: ties are broken by enum declaration order so the
/// same records always yield the same reveal. Never invents a pattern from
/// fewer than [PressurePatternReveal.minEntries] entries.
class PressurePatternRevealEngine {
  const PressurePatternRevealEngine();

  static const _confidenceEngine = PressureEvidenceConfidenceEngine();

  static const _costExamples = [
    'Rest',
    'Clarity',
    'Confidence in stopping',
    'Feeling like enough without doing more',
  ];

  PressurePatternReveal build(List<PressureCheckInRecord> records) {
    if (records.length < PressurePatternReveal.minEntries) {
      return PressurePatternReveal.insufficient();
    }

    final option = _dominantOption(records);
    final context = _repeatedContext(records);
    final fear = _repeatedFear(records);
    final confidence = _confidenceEngine.fromRecords(records);
    final detail = _detailFor(option);

    return PressurePatternReveal(
      hasPattern: true,
      headline: _headline(detail.phrase, context?.label, fear),
      confidence: confidence,
      dominantOptionId: option?.id,
      dominantOptionLabel: option?.label,
      dominantPhrase: detail.phrase,
      repeatedContextId: context?.id,
      repeatedContextLabel: context?.label,
      repeatedFearTheme: fear,
      strongestTrigger: _trigger(detail.trigger, context?.label),
      likelyCost: detail.cost,
      costs: _costExamples,
    );
  }

  String _headline(String phrase, String? contextLabel, String? fear) {
    final buffer = StringBuffer(
      'Your archive is starting to see a pattern: you often $phrase',
    );
    if (contextLabel != null) {
      buffer.write(
        ', especially around ${contextLabel.toLowerCase()} pressure',
      );
    }
    buffer.write('.');
    if (fear != null) {
      buffer.write(
        ' You\'ve named the same worry more than once, so far: '
        '"$fear".',
      );
    }
    return buffer.toString();
  }

  String _trigger(String triggerLabel, String? contextLabel) {
    if (contextLabel == null) return triggerLabel;
    return '$triggerLabel, often around ${contextLabel.toLowerCase()}';
  }

  PressureCheckInOption? _dominantOption(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      counts[record.optionId] = (counts[record.optionId] ?? 0) + 1;
    }
    PressureCheckInOption? best;
    var bestCount = 0;
    // Iterate enum order so ties resolve deterministically.
    for (final option in PressureCheckInOption.values) {
      final count = counts[option.id] ?? 0;
      if (count > bestCount) {
        bestCount = count;
        best = option;
      }
    }
    return best;
  }

  PressureContext? _repeatedContext(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final id in record.contextIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    PressureContext? best;
    var bestCount = 1; // require repetition (>= 2) to count as a pattern.
    for (final context in PressureContext.values) {
      final count = counts[context.id] ?? 0;
      if (count > bestCount) {
        bestCount = count;
        best = context;
      }
    }
    return best;
  }

  /// Only returns a fear the user actually wrote 2+ times (case-insensitive).
  /// Never paraphrases or invents — overclaim-safe.
  String? _repeatedFear(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final record in records) {
      final fear = record.fear?.trim();
      if (fear == null || fear.isEmpty) continue;
      final key = fear.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      display.putIfAbsent(key, () => fear);
    }
    String? best;
    var bestCount = 1;
    counts.forEach((key, count) {
      if (count > bestCount) {
        bestCount = count;
        best = display[key];
      }
    });
    return best;
  }

  _OptionDetail _detailFor(PressureCheckInOption? option) {
    switch (option) {
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return const _OptionDetail(
          phrase: "do more so you won't feel behind",
          trigger: 'Feeling behind',
          cost: 'Rest',
        );
      case PressureCheckInOption.couldNotStop:
        return const _OptionDetail(
          phrase: 'keep going even when you want to stop',
          trigger: "Not being able to stop",
          cost: 'Confidence in stopping',
        );
      case PressureCheckInOption.hadToProveEnough:
        return const _OptionDetail(
          phrase: "push harder to prove you're enough",
          trigger: "Needing to prove you're enough",
          cost: 'Feeling like enough without doing more',
        );
      case PressureCheckInOption.guiltyResting:
        return const _OptionDetail(
          phrase: 'feel guilty when you rest',
          trigger: 'Guilt about resting',
          cost: 'Rest',
        );
      case PressureCheckInOption.keptGoingToFeelProductive:
        return const _OptionDetail(
          phrase: 'keep going to feel productive',
          trigger: 'Keeping going to feel productive',
          cost: 'Clarity',
        );
      case null:
        return const _OptionDetail(
          phrase: 'keep going under pressure',
          trigger: 'Pressure to keep going',
          cost: 'Rest',
        );
    }
  }
}

class _OptionDetail {
  const _OptionDetail({
    required this.phrase,
    required this.trigger,
    required this.cost,
  });

  final String phrase;
  final String trigger;
  final String cost;
}
