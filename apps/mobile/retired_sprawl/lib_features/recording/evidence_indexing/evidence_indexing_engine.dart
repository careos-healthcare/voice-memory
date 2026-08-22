import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Derives citable evidence chips from a saved journal entry.
abstract final class EvidenceIndexingEngine {
  EvidenceIndexingEngine._();

  static const _maxChips = 5;

  static List<EvidenceIndexingChip> extract(JournalEntry entry) {
    final reflection = entry.reflection;
    final chips = <EvidenceIndexingChip>[];

    for (final theme in reflection.recurringThemes) {
      final trimmed = theme.trim();
      if (trimmed.length < 3) continue;
      chips.add(
        EvidenceIndexingChip(
          category: 'Theme Logged',
          label: 'Theme',
          value: trimmed,
        ),
      );
      if (chips.length >= _maxChips) return chips;
    }

    final exact = reflection.exactLanguagePattern.trim();
    if (exact.length >= 12) {
      chips.add(
        EvidenceIndexingChip(
          category: 'Exact Wording',
          label: 'Verbatim phrase',
          value: exact,
        ),
      );
    }

    final mood = reflection.mood.trim();
    if (mood.isNotEmpty) {
      chips.add(
        EvidenceIndexingChip(
          category: 'Emotional Signal',
          label: 'Mood',
          value: mood,
        ),
      );
    }

    final observation = reflection.concreteObservation.trim();
    if (observation.length >= 12) {
      chips.add(
        EvidenceIndexingChip(
          category: 'Observation',
          label: 'Concrete moment',
          value: observation,
        ),
      );
    }

    final tension = reflection.tensionOrContradiction?.trim();
    if (tension != null && tension.length >= 8) {
      chips.add(
        EvidenceIndexingChip(
          category: 'Belief Detected',
          label: 'Tension',
          value: tension,
        ),
      );
    }

    for (final pattern in reflection.patternObservations) {
      final trimmed = pattern.trim();
      if (trimmed.length < 8) continue;
      chips.add(
        EvidenceIndexingChip(
          category: 'Pattern Match',
          label: 'Repeated signal',
          value: trimmed,
        ),
      );
      break;
    }

    final transcript = entry.transcript.trim();
    if (transcript.length >= 20 && chips.length < _maxChips) {
      final snippet = transcript.length > 140
          ? '${transcript.substring(0, 140).trim()}…'
          : transcript;
      chips.add(
        EvidenceIndexingChip(
          category: 'Verbatim Anchor',
          label: 'Recorded moment',
          value: snippet,
        ),
      );
    }

    return chips.take(_maxChips).toList(growable: false);
  }
}