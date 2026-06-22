import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/activation/archive_health_action_plan.dart';
import '../features/activation/archive_health_score.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/archive_insight_feedback.dart';
import '../features/activation/insight_quality_dashboard.dart';
import '../features/archive_proof/visible_archive_proof_copy.dart';
import '../models/journal_entry.dart';
import '../security/sensitive_screen_guard.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../services/app_services.dart';
import '../widgets/archive/archive_health_action_plan_card.dart';
import '../widgets/archive/archive_health_card.dart';
import '../widgets/archive/insight_quality_dashboard_card.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';

/// Local-only dashboard for reviewing and managing insight feedback.
class InsightQualityScreen extends StatefulWidget {
  const InsightQualityScreen({super.key});

  @override
  State<InsightQualityScreen> createState() => _InsightQualityScreenState();
}

class _InsightQualityScreenState extends State<InsightQualityScreen> {
  bool _loading = true;
  InsightQualitySummary _summary = const InsightQualitySummary(
    feelsRightCount: 0,
    notQuiteCount: 0,
    hiddenCount: 0,
    correctionNoteCount: 0,
  );
  List<InsightQualityEntry> _notQuiteEntries = const [];
  List<InsightQualityEntry> _hiddenEntries = const [];
  List<InsightQualityEntry> _noteEntries = const [];
  ArchiveHealthScore _archiveHealth = ArchiveHealthScore.hidden();
  ArchiveHealthActionPlan _actionPlan = ArchiveHealthActionPlan.hidden();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ArchiveInsightFeedbackStore.ensureLoaded();
    final entries = AppServices.isInitialized
        ? await AppServices.instance.journal.loadAll()
        : const <JournalEntry>[];
    if (!mounted) return;
    setState(() {
      _summary = InsightQualityDashboardEngine.buildSummary();
      _notQuiteEntries = InsightQualityDashboardEngine.notQuiteEntries();
      _hiddenEntries = InsightQualityDashboardEngine.hiddenEntries();
      _noteEntries = InsightQualityDashboardEngine.correctionNoteEntries();
      _archiveHealth = ArchiveHealthScoreEngine.build(entries: entries);
      _actionPlan = ArchiveHealthActionPlanEngine.build(entries: entries);
      _loading = false;
    });
  }

  Future<void> _editNote(String insightId, {String? initialNote}) async {
    final controller = TextEditingController(text: initialNote ?? '');
    final saved = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(VisibleArchiveProofCopy.insightQualityEditNoteCta),
        content: TextField(
          key: const Key('insight_quality_edit_note_field'),
          controller: controller,
          maxLength: ArchiveInsightFeedbackStore.maxCorrectionNoteLength,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: ArchiveInsightFeedbackCopy.correctionPlaceholder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ArchiveInsightFeedbackCopy.correctionSkipCta),
          ),
          TextButton(
            key: const Key('insight_quality_edit_note_save'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(ArchiveInsightFeedbackCopy.correctionSaveCta),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null) return;
    ArchiveInsightFeedbackStore.saveCorrectionNote(insightId, saved);
    await _load();
  }

  Future<void> _deleteNote(String insightId) async {
    ArchiveInsightFeedbackStore.deleteCorrectionNote(insightId);
    await _load();
  }

  Future<void> _clearFeedback(String insightId) async {
    ArchiveInsightFeedbackStore.clearFeedback(insightId);
    await _load();
  }

  Future<void> _unhide(String insightId) async {
    ArchiveInsightFeedbackStore.unhide(insightId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ArchiveMobileSpacing.pagePadding,
                    children: [
                      const ConsumerScreenBackHeader(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        VisibleArchiveProofCopy.insightQualityTitle,
                        key: const Key('insight_quality_screen_title'),
                        style: VoiceMemoryTypography.headlineStyle(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        VisibleArchiveProofCopy.insightQualitySubtitle,
                        key: const Key('insight_quality_screen_subtitle'),
                        style: VoiceMemoryTypography.bodyStyle(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      InsightQualitySummaryCard(summary: _summary),
                      if (_archiveHealth.showCard) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ArchiveHealthCard(score: _archiveHealth),
                      ],
                      if (_actionPlan.showCard) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ArchiveHealthActionPlanCard(
                          plan: _actionPlan,
                          onPrimary: () => context.go('/record'),
                          onSecondary: _actionPlan.secondaryAction ==
                                  ArchiveHealthActionPlanCta.viewEvidence
                              ? () => context.push(
                                    BeliefEvidenceNavigation.route,
                                  )
                              : null,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (_summary.isEmpty) ...[
                        Text(
                          VisibleArchiveProofCopy.insightQualityEmptyHeading,
                          style: VoiceMemoryTypography.sectionTitleStyle(),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          VisibleArchiveProofCopy.insightQualityEmptyBody,
                          style: VoiceMemoryTypography.bodyStyle(),
                        ),
                      ] else ...[
                        if (_notQuiteEntries.isNotEmpty)
                          _section(
                            headingKey: const Key(
                              'insight_quality_not_quite_section',
                            ),
                            title: VisibleArchiveProofCopy
                                .insightQualityNotQuiteHeading,
                            children: _notQuiteEntries
                                .map(
                                  (entry) => _entryTile(
                                    entry: entry,
                                    key: Key(
                                      'insight_quality_not_quite_${entry.insightId}',
                                    ),
                                    actions: [
                                      TextButton(
                                        key: Key(
                                          'insight_quality_edit_note_${entry.insightId}',
                                        ),
                                        onPressed: () => _editNote(
                                          entry.insightId,
                                          initialNote: entry.correctionNote,
                                        ),
                                        child: Text(
                                          VisibleArchiveProofCopy
                                              .insightQualityEditNoteCta,
                                        ),
                                      ),
                                      TextButton(
                                        key: Key(
                                          'insight_quality_clear_${entry.insightId}',
                                        ),
                                        onPressed: () =>
                                            _clearFeedback(entry.insightId),
                                        child: Text(
                                          VisibleArchiveProofCopy
                                              .insightQualityClearFeedbackCta,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        if (_hiddenEntries.isNotEmpty)
                          _section(
                            headingKey: const Key(
                              'insight_quality_hidden_section',
                            ),
                            title:
                                VisibleArchiveProofCopy.insightQualityHiddenHeading,
                            children: _hiddenEntries
                                .map(
                                  (entry) => _entryTile(
                                    entry: entry,
                                    key: Key(
                                      'insight_quality_hidden_${entry.insightId}',
                                    ),
                                    actions: [
                                      TextButton(
                                        key: Key(
                                          'insight_quality_unhide_${entry.insightId}',
                                        ),
                                        onPressed: () => _unhide(entry.insightId),
                                        child: Text(
                                          VisibleArchiveProofCopy
                                              .insightQualityUnhideCta,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        if (_noteEntries.isNotEmpty)
                          _section(
                            headingKey: const Key(
                              'insight_quality_notes_section',
                            ),
                            title: VisibleArchiveProofCopy
                                .insightQualityNotesHeading,
                            children: _noteEntries
                                .map(
                                  (entry) => _entryTile(
                                    entry: entry,
                                    key: Key(
                                      'insight_quality_note_${entry.insightId}',
                                    ),
                                    showNotePreview: true,
                                    actions: [
                                      TextButton(
                                        onPressed: () => _editNote(
                                          entry.insightId,
                                          initialNote: entry.correctionNote,
                                        ),
                                        child: Text(
                                          VisibleArchiveProofCopy
                                              .insightQualityEditNoteCta,
                                        ),
                                      ),
                                      TextButton(
                                        key: Key(
                                          'insight_quality_delete_note_${entry.insightId}',
                                        ),
                                        onPressed: () =>
                                            _deleteNote(entry.insightId),
                                        child: Text(
                                          VisibleArchiveProofCopy
                                              .insightQualityDeleteNoteCta,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        VisibleArchiveProofCopy.insightQualityPrivacyHeading,
                        style: VoiceMemoryTypography.sectionTitleStyle(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        VisibleArchiveProofCopy.insightQualityPrivacyDevice,
                        key: const Key('insight_quality_privacy_device'),
                        style: VoiceMemoryTypography.bodyStyle(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        VisibleArchiveProofCopy.insightQualityPrivacyNotes,
                        key: const Key('insight_quality_privacy_notes'),
                        style: VoiceMemoryTypography.bodyStyle(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        VisibleArchiveProofCopy.insightQualityPrivacyShareSafe,
                        key: const Key('insight_quality_privacy_share_safe'),
                        style: VoiceMemoryTypography.bodyStyle(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _section({
    required Key headingKey,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, key: headingKey, style: VoiceMemoryTypography.sectionTitleStyle()),
        const SizedBox(height: AppSpacing.sm),
        ...children,
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _entryTile({
    required InsightQualityEntry entry,
    required Key key,
    required List<Widget> actions,
    bool showNotePreview = false,
  }) {
    return Card(
      key: key,
      color: AppColors.backgroundSecondary,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.label, style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontWeight: FontWeight.w600,
            )),
            if (entry.cautionStatus case final caution?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                caution,
                key: Key('insight_quality_caution_${entry.insightId}'),
                style: VoiceMemoryTypography.bodyStyle(),
              ),
            ],
            if (entry.correctionNote case final note?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                showNotePreview
                    ? '${ArchiveInsightFeedbackCopy.correctionYourNotePrefix} $note'
                    : note,
                key: Key('insight_quality_note_preview_${entry.insightId}'),
                style: VoiceMemoryTypography.bodyStyle(),
                maxLines: showNotePreview ? null : 2,
                overflow: showNotePreview ? null : TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: 4, runSpacing: 0, children: actions),
          ],
        ),
      ),
    );
  }
}
