import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../belief_evolution/belief_evolution_models.dart';
import '../discover/belief_engine.dart';
import '../identity_engine/identity_engine.dart';
import 'archive_analyst_models.dart';
import 'archive_belief_visibility.dart';

/// Collects belief hypotheses from existing engines only.
class ArchiveAnalystBeliefCatalog {
  const ArchiveAnalystBeliefCatalog({
    this.beliefEngine = const DiscoverBeliefEngine(),
    this.identityEngine = const IdentityEngine(),
  });

  final DiscoverBeliefEngine beliefEngine;
  final IdentityEngine identityEngine;

  List<ArchiveAnalystBeliefCandidate> collect({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    BeliefEvolutionState? evolution,
  }) {
    final seen = <String>{};
    final out = <ArchiveAnalystBeliefCandidate>[];

    void add(String statement, String source, {DateTime? lastUpdated}) {
      final norm = _normalize(statement);
      if (norm.length < 12 || !seen.add(norm)) return;
      out.add(
        ArchiveAnalystBeliefCandidate(
          id: 'belief:${norm.hashCode.abs()}',
          statement: statement.trim(),
          source: source,
          lastUpdated: lastUpdated,
        ),
      );
    }

    final card = beliefEngine.build(entries: entries, state: state);
    if (card != null && !card.statement.contains('still gathering evidence')) {
      add(card.statement, 'primary_belief', lastUpdated: card.lastReinforced);
    }

    final stateBelief = state?.belief?.trim() ?? '';
    if (stateBelief.isNotEmpty) {
      add(stateBelief, 'archive_state');
    }

    if (evolution != null) {
      for (final v in evolution.versions) {
        add(
          v.beliefText,
          'belief_evolution',
          lastUpdated: DateTime.tryParse(v.recordedAt),
        );
      }
    }

    final profile = identityEngine.build(entries: entries);
    for (final t in [
      ...profile.currentTraits,
      ...profile.emergingTraits,
      ...profile.decliningTraits,
    ]) {
      if (ArchiveBeliefVisibility.isTraitOrPlaceholder(t.title)) continue;
      add(t.title, 'identity_trait', lastUpdated: t.lastSeen);
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final obsCounts = <String, int>{};
    for (final e in eligible) {
      final obs = e.reflection.concreteObservation.trim();
      if (obs.length < 16) continue;
      final key = _normalize(obs);
      obsCounts[key] = (obsCounts[key] ?? 0) + 1;
      if ((obsCounts[key] ?? 0) == 2) {
        add(obs, 'repeated_observation', lastUpdated: e.createdAt);
      }
    }

    return out;
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
