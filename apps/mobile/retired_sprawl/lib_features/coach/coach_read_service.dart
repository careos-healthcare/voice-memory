import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_controller.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/contradiction_detection/contradiction_detection_service.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

class CoachSessionInsightRow {
  const CoachSessionInsightRow({
    required this.kind,
    required this.title,
    required this.summary,
    required this.citedEntryIds, this.confidenceBand,
  });

  final ArchiveInsightKind kind;
  final String title;
  final String summary;
  final String? confidenceBand;
  final List<String> citedEntryIds;
}

class CoachDashboardSnapshot {
  const CoachDashboardSnapshot({
    required this.clientLabel,
    required this.beliefs,
    required this.blindSpots,
    required this.contradictions,
    required this.factLedgerLabels,
  });

  final String clientLabel;
  final List<CoachSessionInsightRow> beliefs;
  final List<CoachSessionInsightRow> blindSpots;
  final List<CoachSessionInsightRow> contradictions;
  final List<String> factLedgerLabels;
}

/// Read-only coach session-planning surface — no caregiver monitoring paths.
class CoachReadService {
  CoachReadService({
    required this._journalStore,
    required this._factLedgerStore,
    required this._modeController,
    ArchiveExplanationEngine? explanationEngine,
    ContradictionDetectionService? contradictionService,
  })  : _explanationEngine = explanationEngine ?? const ArchiveExplanationEngine(),
        _contradictionService =
            contradictionService ?? const ContradictionDetectionService();

  final JournalStore _journalStore;
  final FactLedgerStore _factLedgerStore;
  final CoachModeController _modeController;
  final ArchiveExplanationEngine _explanationEngine;
  final ContradictionDetectionService _contradictionService;

  Future<CoachDashboardSnapshot?> loadDashboardSnapshot() async {
    final allowed = await _modeController.ensureCoachReadAllowed(
      resourceType: 'coach_dashboard',
      resourceId: 'session_planning',
    );
    if (!allowed) return null;

    final session = _modeController.activeSession;
    if (session == null) return null;

    final permissions = session.permissions;
    final entries = await _journalStore.loadEligible();

    final beliefs = permissions.allowsInsightKind(ArchiveInsightKind.belief)
        ? _buildBeliefs(entries, permissions)
        : const <CoachSessionInsightRow>[];
    final blindSpots =
        permissions.allowsInsightKind(ArchiveInsightKind.blindSpot)
            ? _buildBlindSpots(entries, permissions)
            : const <CoachSessionInsightRow>[];
    final contradictions =
        permissions.allowsInsightKind(ArchiveInsightKind.contradiction)
            ? await _buildContradictions(entries, permissions)
            : const <CoachSessionInsightRow>[];

    final factLedgerLabels = permissions.factLedger
        ? await _loadFactLedgerLabels()
        : const <String>[];

    return CoachDashboardSnapshot(
      clientLabel: session.clientAccountId,
      beliefs: beliefs,
      blindSpots: blindSpots,
      contradictions: contradictions,
      factLedgerLabels: factLedgerLabels,
    );
  }

  List<CoachSessionInsightRow> _buildBeliefs(
    List<JournalEntry> entries,
    CoachSharingPermissions permissions,
  ) {
    final explanation = _explanationEngine.buildExplanation(
      ref: ArchiveInsightRef.belief(),
      entries: entries,
    );
    if (explanation == null) return const [];
    return [
      _rowFromExplanation(explanation, permissions),
    ];
  }

  List<CoachSessionInsightRow> _buildBlindSpots(
    List<JournalEntry> entries,
    CoachSharingPermissions permissions,
  ) {
    final explanation = _explanationEngine.buildExplanation(
      ref: ArchiveInsightRef.blindSpot('session-planning'),
      entries: entries,
    );
    if (explanation == null) return const [];
    return [
      _rowFromExplanation(explanation, permissions),
    ];
  }

  Future<List<CoachSessionInsightRow>> _buildContradictions(
    List<JournalEntry> entries,
    CoachSharingPermissions permissions,
  ) async {
    final report = _contradictionService.detect(entries: entries);
    if (report.reports.isEmpty) return const [];

    final rows = <CoachSessionInsightRow>[];
    for (final pair in report.reports.take(3)) {
      final explanation = _explanationEngine.buildExplanation(
        ref: ArchiveInsightRef.contradiction(
          entryIdA: pair.originalEntryId,
          entryIdB: pair.conflictingEntryId,
        ),
        entries: entries,
      );
      if (explanation == null) continue;
      rows.add(_rowFromExplanation(explanation, permissions));
    }
    return rows;
  }

  Future<List<String>> _loadFactLedgerLabels() async {
    final facts = await _factLedgerStore.loadAll();
    return facts
        .take(8)
        .map((fact) {
          final label = fact.label.trim();
          final value = fact.value.trim();
          if (label.isEmpty && value.isEmpty) return '';
          if (value.isEmpty) return label;
          return '$label — $value';
        })
        .where((line) => line.isNotEmpty)
        .toList();
  }

  CoachSessionInsightRow _rowFromExplanation(
    ArchiveExplanation explanation,
    CoachSharingPermissions permissions,
  ) {
    final cited = explanation.supportingEvidence
        .map((item) => item.entryId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return CoachSessionInsightRow(
      kind: explanation.kind,
      title: explanation.title,
      summary: explanation.whySummary.trim().isNotEmpty
          ? explanation.whySummary
          : explanation.explanation,
      confidenceBand: permissions.confidenceBandedInsights
          ? _confidenceBand(explanation.confidence)
          : null,
      citedEntryIds: cited,
    );
  }

  String _confidenceBand(double confidence) {
    if (confidence >= 0.75) return 'strong';
    if (confidence >= 0.55) return 'solid';
    if (confidence >= 0.35) return 'emerging';
    return 'weak';
  }
}