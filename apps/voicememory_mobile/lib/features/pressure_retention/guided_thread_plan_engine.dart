import 'guided_thread_plan_model.dart';
import 'pressure_check_in_record.dart';
import 'thread_return_evidence_engine.dart';
import 'thread_return_evidence_model.dart';

/// Builds a [GuidedThreadPlan] from the same thread evidence the Thread
/// Return card uses — pure, deterministic, no AI calls.
///
/// The plan reframes existing evidence as a light "yesterday → today"
/// structure:
/// - "Already covered" reports what the user genuinely named and logged.
/// - "Worth checking" offers 1–3 open items shaped by the thread status.
/// - One next prompt turns the thread into a single small recording.
///
/// Nothing is ever marked resolved. Only a fading thread earns the cautious
/// "may be settling" line — real reduced recurrence, hedged wording.
class GuidedThreadPlanEngine {
  const GuidedThreadPlanEngine();

  static const ThreadReturnEvidenceEngine _threadEngine =
      ThreadReturnEvidenceEngine();

  /// [now] is injectable for tests and forwarded to the thread engine.
  GuidedThreadPlan build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    final evidence = _threadEngine.build(records, now: now);
    if (!evidence.hasEvidence ||
        evidence.occurrenceCount < GuidedThreadPlan.minRelatedEntries ||
        evidence.sourceTerms.isEmpty) {
      return GuidedThreadPlan.none();
    }

    return GuidedThreadPlan(
      hasPlan: true,
      alreadyCovered: _alreadyCovered(evidence),
      worthChecking: _worthChecking(evidence.status),
      nextPrompt: _nextPrompt(evidence),
      sourceTerms:
          evidence.sourceTerms.take(GuidedThreadPlan.maxTerms).toList(),
      evidenceSnippets:
          evidence.evidenceSnippets.take(GuidedThreadPlan.maxSnippets).toList(),
      entryIds: evidence.entryIds,
    );
  }

  /// What the user already did — their own terms and real counts. The only
  /// settling language is the hedged fading line; nothing is "resolved".
  List<String> _alreadyCovered(ThreadReturnEvidence evidence) {
    final term = evidence.sourceTerms.first;
    final count = evidence.occurrenceCount;
    final lines = <String>[
      'You already named the $term thread.',
      'You already logged $count moments on it.',
    ];
    if (evidence.status == ThreadReturnStatus.fading) {
      lines.add('The $term thread may be settling.');
    } else if (evidence.sourceTerms.length > 1) {
      lines.add(
        'You already noticed ${evidence.sourceTerms[1]} showing up with it.',
      );
    }
    return lines.take(GuidedThreadPlan.maxAlreadyCovered).toList();
  }

  /// Short open items shaped by where the thread currently stands.
  List<String> _worthChecking(ThreadReturnStatus status) {
    switch (status) {
      case ThreadReturnStatus.returned:
        return const [
          'What it made you do this time',
          'What changed since yesterday',
        ];
      case ThreadReturnStatus.building:
        return const [
          'Whether it shows up again today',
          'What changed since yesterday',
        ];
      case ThreadReturnStatus.fading:
        return const [
          'What felt easier this time',
          'Whether it stayed quiet today',
        ];
      case ThreadReturnStatus.earlySignal:
        return const [
          'Whether it came back today',
          'What changed since yesterday',
        ];
    }
  }

  /// One clear prompt using the user's own thread term.
  String _nextPrompt(ThreadReturnEvidence evidence) {
    final term = evidence.sourceTerms.first;
    switch (evidence.status) {
      case ThreadReturnStatus.returned:
        return 'What happened with the $term thread today?';
      case ThreadReturnStatus.building:
        return 'What did the $term thread make you do today?';
      case ThreadReturnStatus.fading:
        return 'What felt different about $term today?';
      case ThreadReturnStatus.earlySignal:
        return 'Did the $term thread return, fade, or change today?';
    }
  }
}
