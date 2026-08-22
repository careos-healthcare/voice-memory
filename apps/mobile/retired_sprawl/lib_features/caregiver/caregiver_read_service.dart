import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Read-only caregiver data access with mandatory audit logging.
class CaregiverReadService {
  CaregiverReadService({
    required this._journalStore,
    required this._modeController,
  });

  final JournalStore _journalStore;
  final CaregiverModeController _modeController;

  Future<CaregiverDashboardSnapshot?> loadDashboardSnapshot() async {
    final allowed = await _modeController.ensureReadAllowed(
      streamId: CaregiverPermissions.journalStream,
      auditAction: CaregiverAuditAction.dashboardViewed,
      resourceId: 'dashboard',
    );
    if (!allowed) return null;

    final entries = await _journalStore.loadEligible();

    // No snapshot field derives from the proof trail, so this call records the
    // read decision without having anything to withhold on a denial. Bind the
    // result before returning proof-trail data here.
    await _modeController.ensureReadAllowed(
      streamId: CaregiverPermissions.proofTrailStream,
      auditAction: CaregiverAuditAction.evidenceStreamRead,
      resourceId: 'proof_trail',
    );

    // The summaries section is derived from the timeline stream and rendered as
    // a review summary, so it is two separate consent choices. Declining either
    // withholds it.
    final timelineAllowed = await _modeController.ensureReadAllowed(
      streamId: CaregiverPermissions.timelineStream,
      auditAction: CaregiverAuditAction.evidenceStreamRead,
      resourceId: 'timeline',
    );
    final summariesAllowed = await _modeController.ensureReadAllowed(
      streamId: CaregiverPermissions.reviewSummariesStream,
      auditAction: CaregiverAuditAction.reviewSummaryRead,
      resourceId: 'timeline_summary',
    );
    final timeline = timelineAllowed && summariesAllowed
        ? _buildTimelineSummaries(entries)
        : const <String>[];

    final alertsAllowed = await _modeController.ensureReadAllowed(
      streamId: CaregiverPermissions.insightAlertsStream,
      auditAction: CaregiverAuditAction.thresholdAlertRead,
      resourceId: 'insight_alerts',
    );
    final alerts =
        alertsAllowed ? _buildThresholdAlerts(entries) : const <String>[];

    return CaregiverDashboardSnapshot(
      evidenceCount: entries.length,
      recentEvidenceLabels: entries
          .take(5)
          .map(_safeLabel)
          .where((label) => label.isNotEmpty)
          .toList(),
      timelineSummaries: timeline,
      priorityAlerts: alerts,
    );
  }

  List<String> _buildTimelineSummaries(List<JournalEntry> entries) {
    if (entries.isEmpty) return const [];
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted
        .take(3)
        .map((entry) {
          final date = entry.createdAt.toLocal().toString().split(' ').first;
          final label = _safeLabel(entry);
          if (label.isEmpty) return 'Moment on $date';
          return '$date — $label';
        })
        .toList();
  }

  List<String> _buildThresholdAlerts(List<JournalEntry> entries) {
    if (entries.length < 3) return const [];
    return [
      'Archive has ${entries.length} preserved moments — review recent changes together.',
    ];
  }

  String _safeLabel(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) return '';
    if (transcript.length <= 72) return transcript;
    return '${transcript.substring(0, 72)}…';
  }
}

class CaregiverDashboardSnapshot {
  const CaregiverDashboardSnapshot({
    required this.evidenceCount,
    required this.recentEvidenceLabels,
    required this.timelineSummaries,
    required this.priorityAlerts,
  });

  final int evidenceCount;
  final List<String> recentEvidenceLabels;
  final List<String> timelineSummaries;
  final List<String> priorityAlerts;
}