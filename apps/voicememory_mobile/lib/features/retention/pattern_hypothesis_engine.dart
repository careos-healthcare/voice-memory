import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../first_session/first_session_pattern_engine.dart';
import '../post_save_insight/selected_signal_coordinator.dart';
import '../post_save_insight/selected_signal_model.dart';
import 'pattern_hypothesis_model.dart';
import 'second_session_signal_engine.dart';

/// Builds a working hypothesis from saved moments — no network AI.
class PatternHypothesisEngine {
  const PatternHypothesisEngine();

  static const _patternEngine = FirstSessionPatternEngine();
  static const _compareEngine = SecondSessionSignalEngine();

  Future<PatternHypothesis> build(List<JournalEntry> entries) async {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) {
      return PatternHypothesis.insufficient();
    }

    final selected = await SelectedSignalCoordinator.loadCurrent();
    final latest = eligible.last;
    final latestPattern = _patternEngine.build(latest);
    final comparison = _compareEngine.build(entries);

    final evidence = _evidenceLines(eligible, selected, latestPattern.chips);
    final patternMightBe = selected?.title.trim().isNotEmpty == true
        ? selected!.title
        : latestPattern.title;

    final wouldProveWrong = latestPattern.categoryId == 'lighter'
        ? 'If your next moments feel heavier, rushed, or pressured again.'
        : 'If your next moments are more about excitement, curiosity, or choice.';

    final watchNext = selected?.nextPrompt.trim().isNotEmpty == true
        ? selected!.nextPrompt
        : (comparison.whatToTestNext ??
            'Notice whether ${latestPattern.watchForText}.');

    return PatternHypothesis(
      hasEnoughData: true,
      patternMightBe: patternMightBe,
      evidenceSoFar: evidence,
      wouldProveWrong: wouldProveWrong,
      watchNext: watchNext,
      reflectionCount: eligible.length,
    );
  }

  List<String> _evidenceLines(
    List<JournalEntry> eligible,
    SelectedSignalRecord? selected,
    List<String> chips,
  ) {
    final out = <String>[];
    if (selected != null) {
      for (final c in selected.evidenceChips) {
        out.add('You mentioned $c.');
        if (out.length >= 3) return out;
      }
      if (selected.whySuggested?.trim().isNotEmpty == true) {
        out.add(selected.whySuggested!.trim());
      }
    }
    for (final chip in chips) {
      final line = 'You mentioned $chip.';
      if (!out.contains(line)) out.add(line);
      if (out.length >= 3) break;
    }
    if (out.isEmpty && eligible.length >= 2) {
      out.add('You recorded ${eligible.length} moments that may connect.');
    }
    return out.take(3).toList();
  }
}
