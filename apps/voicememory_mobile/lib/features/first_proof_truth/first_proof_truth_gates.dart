import '../../models/journal_entry.dart';
import '../first_proof_payoff/first_proof_payoff_model.dart';
import 'first_proof_truth_store.dart';

/// Visibility gates for the first proof truth follow-up card.
abstract final class FirstProofTruthGates {
  FirstProofTruthGates._();

  static bool shouldShow({
    required bool showFirstProofPayoff,
    required FirstProofPayoff? payoff,
    required List<JournalEntry> entries,
    required String proofKey,
    required bool hasAnsweredForProof,
  }) =>
      showFirstProofPayoff &&
      payoff != null &&
      proofKey.isNotEmpty &&
      !hasAnsweredForProof;

  static String proofKeyForEntries(List<JournalEntry> entries) =>
      FirstProofTruthStore.proofKeyForFirstProof(entries);
}
