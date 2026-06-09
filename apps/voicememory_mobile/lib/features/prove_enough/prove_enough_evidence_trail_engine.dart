import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import '../signal_journey/signal_journey_model.dart';
import '../signal_review/signal_review_model.dart';
import 'loop_trigger_map_engine.dart';
import 'next_evidence_mission_model.dart';
import 'prove_enough_contradiction_model.dart';
import 'prove_enough_evidence_trail_model.dart';
import 'prove_enough_post_record_engine.dart';
import 'prove_enough_post_record_model.dart';

/// Builds the prove_enough full evidence trail from real saved moments.
class ProveEnoughEvidenceTrailEngine {
  const ProveEnoughEvidenceTrailEngine();

  static const _excerptMaxChars = 88;
  static const _postEngine = ProveEnoughPostRecordEngine();
  static const _triggerEngine = LoopTriggerMapEngine();
  static const _loopEngine = LoopModeEngine();

  ProveEnoughEvidenceTrail build({
    required List<JournalEntry> entries,
    SignalJourney? journey,
    SignalReview? review,
    List<ProveEnoughContradictionRecord> contradictions = const [],
    NextEvidenceMissionModel? latestMission,
  }) {
    final activeLoop = _loopEngine.activate(LoopModeIds.proveEnough);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final byId = {for (final entry in eligible) entry.id: entry};

    final supporting = <ProveEnoughEvidenceMoment>[];
    final contradiction = <ProveEnoughEvidenceMoment>[];
    final restGuilt = <ProveEnoughEvidenceMoment>[];
    final choice = <ProveEnoughEvidenceMoment>[];
    final seenSupporting = <String>{};
    final seenContradiction = <String>{};
    final seenRest = <String>{};
    final seenChoice = <String>{};

    void addMoment(
      List<ProveEnoughEvidenceMoment> target,
      Set<String> seen,
      JournalEntry entry,
    ) {
      if (seen.contains(entry.id)) return;
      final excerpt = _excerptFromTranscript(entry);
      if (excerpt.isEmpty) return;
      seen.add(entry.id);
      target.add(
        ProveEnoughEvidenceMoment(
          entryId: entry.id,
          createdAt: entry.createdAt,
          excerpt: excerpt,
        ),
      );
    }

    for (final id in journey?.supportingMomentIds ?? const <String>[]) {
      final entry = byId[id];
      if (entry != null) addMoment(supporting, seenSupporting, entry);
    }

    for (final id in journey?.contradictingMomentIds ?? const <String>[]) {
      final entry = byId[id];
      if (entry != null) addMoment(contradiction, seenContradiction, entry);
    }

    for (final record in contradictions) {
      final entryId = record.entryId;
      if (entryId != null) {
        final entry = byId[entryId];
        if (entry != null) {
          addMoment(contradiction, seenContradiction, entry);
          continue;
        }
      }
      if (seenContradiction.add(record.id)) {
        contradiction.add(
          ProveEnoughEvidenceMoment(
            entryId: record.id,
            createdAt: record.savedAt,
            excerpt: record.label,
          ),
        );
      }
    }

    for (final entry in eligible) {
      final postRecord = _postEngine.analyze(
        entryId: entry.id,
        transcript: entry.transcript,
        interpretationReads: const [],
        activeLoop: activeLoop,
      );

      if (_isSupporting(postRecord, journey: journey, entryId: entry.id)) {
        addMoment(supporting, seenSupporting, entry);
      }
      if (_isContradiction(postRecord)) {
        addMoment(contradiction, seenContradiction, entry);
      }
      if (postRecord.restGuiltPresent) {
        addMoment(restGuilt, seenRest, entry);
      }
      if (_isChoiceMoment(postRecord)) {
        addMoment(choice, seenChoice, entry);
      }
    }

    supporting.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    contradiction.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    restGuilt.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    choice.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final triggerMap = _triggerEngine.build(eligible);
    final triggerSummary = triggerMap.hasEnoughData
        ? triggerMap.rankedRows
            .map((row) => '${row.category.label} (${row.count})')
            .join('\n')
        : '';

    return ProveEnoughEvidenceTrail(
      supportingMoments: supporting,
      contradictionMoments: contradiction,
      restGuiltMoments: restGuilt,
      choiceMoments: choice,
      triggerSummary: triggerSummary,
      whatChanged: review?.whatChanged.trim() ?? '',
      latestMission: latestMission?.mission,
    );
  }

  bool _isSupporting(
    ProveEnoughPostRecordModel postRecord, {
    SignalJourney? journey,
    required String entryId,
  }) {
    if (journey?.supportingMomentIds.contains(entryId) == true) return true;
    if (postRecord.transcriptWeak) return false;
    return postRecord.pressureLevel != ProveEnoughLevel.low ||
        postRecord.enoughnessScore >= 36;
  }

  bool _isContradiction(ProveEnoughPostRecordModel postRecord) {
    if (postRecord.transcriptWeak) return false;
    return postRecord.choiceLevel != ProveEnoughLevel.low &&
        postRecord.pressureLevel == ProveEnoughLevel.low &&
        postRecord.enoughnessScore <= 35;
  }

  bool _isChoiceMoment(ProveEnoughPostRecordModel postRecord) {
    if (postRecord.transcriptWeak) return false;
    return postRecord.choiceLevel != ProveEnoughLevel.low &&
        postRecord.whatLookedLikeChoice.isNotEmpty;
  }

  String _excerptFromTranscript(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.length < ArchiveEvidenceGuard.minimumTranscriptChars) {
      return '';
    }
    return _truncate(transcript.replaceAll(RegExp(r'\s+'), ' '));
  }

  String _truncate(String raw) {
    if (raw.length <= _excerptMaxChars) return raw;
    return '${raw.substring(0, _excerptMaxChars - 1).trim()}…';
  }
}
