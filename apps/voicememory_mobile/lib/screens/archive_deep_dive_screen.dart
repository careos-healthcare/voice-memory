import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../features/archive_deep_dive/archive_deep_dive_copy.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/archive_deep_dive/archive_deep_dive_engine.dart';
import '../features/archive_deep_dive/archive_deep_dive_gate.dart';
import '../features/archive_deep_dive/archive_deep_dive_models.dart';
import '../features/archive_deep_dive/archive_deep_dive_reflection_service.dart';
import '../features/archive_synthesis/archive_synthesis_copy.dart';
import '../features/archive_synthesis/archive_synthesis_models.dart';
import '../features/archive_synthesis/archive_synthesis_pro_gate.dart';
import '../features/archive_synthesis/archive_synthesis_service.dart';
import '../features/archive_synthesis/archive_synthesis_store.dart';
import '../widgets/archive_v1/archive_intelligence_upgrade_card.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive_evidence_panel.dart';
import '../widgets/belief_evolution_timeline.dart';
import '../widgets/pushed_screen_shell.dart';

/// Evidence-backed belief exploration — local engines only.
class ArchiveDeepDiveScreen extends StatefulWidget {
  const ArchiveDeepDiveScreen({super.key, required this.v1});

  final ArchiveV1View v1;

  @override
  State<ArchiveDeepDiveScreen> createState() => _ArchiveDeepDiveScreenState();
}

class _ArchiveDeepDiveScreenState extends State<ArchiveDeepDiveScreen> {
  ArchiveDeepDiveView? _view;
  ArchiveDeepDiveNarrative? _narrative;
  bool _narrativeLoading = false;
  bool _showNarrativeUpgrade = false;
  final _responseControllers = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    First25UserMetrics.trackDeepDiveOpened(surface: 'archive_deep_dive_screen');
    _view = const ArchiveDeepDiveEngine().build(v1: widget.v1);
    for (final q in _view?.inquiryQuestions ?? const []) {
      _responseControllers[q.id] = TextEditingController();
    }
    _loadNarrative();
  }

  Future<void> _loadNarrative() async {
    final dive = _view;
    if (dive == null || !AppConfig.enableGpt5ArchiveSynthesis) return;
    setState(() => _narrativeLoading = true);
    try {
      final s = AppServices.instance;
      final entitlements = await s.billing.loadEntitlements();
      if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
        if (!mounted) return;
        setState(() {
          _showNarrativeUpgrade =
              ArchiveSynthesisProGate.shouldShowUpgradeTeaser(widget.v1);
          _narrative = null;
        });
        return;
      }
      final result =
          await ArchiveSynthesisService(
            store: ArchiveSynthesisStore(s.prefs),
            api: s.api,
            deviceIds: s.deviceIds,
          ).loadDeepDiveNarrative(
            view: widget.v1,
            dive: dive,
            entitlements: entitlements,
            userId: s.auth.currentSession?.userId,
          );
      if (!mounted) return;
      if (result.showSection) {
        setState(() {
          _narrative = result.narrative;
          _showNarrativeUpgrade = false;
        });
      }
    } finally {
      if (mounted) setState(() => _narrativeLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _responseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveInquiry(ArchiveDeepDiveInquiryQuestion question) async {
    final text = _responseControllers[question.id]?.text ?? '';
    if (text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final service = ArchiveDeepDiveReflectionService(
        AppServices.instance.journalStore,
      );
      await service.saveInquiryResponse(
        beliefStatement: _view!.beliefStatement,
        question: question,
        responseText: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ArchiveDeepDiveCopy.reflectionSaved)),
        );
        _responseControllers[question.id]?.clear();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveDeepDiveGate.canOpenDeepDive(widget.v1)) {
      return PushedScreenShell(
        title: ArchiveDeepDiveCopy.screenTitle,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              ArchiveDeepDiveCopy.insufficientEvidence,
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ),
        ),
      );
    }

    final dive = _view;
    if (dive == null) {
      return PushedScreenShell(
        title: ArchiveDeepDiveCopy.screenTitle,
        body: const Center(
          child: Text(
            ArchiveDeepDiveCopy.insufficientEvidence,
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: ArchiveDeepDiveCopy.screenTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionLabel('CURRENT BELIEF'),
          const SizedBox(height: 8),
          Text(
            '"${dive.beliefStatement}"',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confidence: ${dive.confidencePercent}%',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            ArchiveDeepDiveCopy.interpretationDisclaimer,
            style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.45),
          ),
          if (_narrativeLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (_showNarrativeUpgrade) ...[
            const SizedBox(height: 20),
            ArchiveIntelligenceUpgradeCard(view: widget.v1, compact: true),
          ],
          if (_narrative != null) ...[
            const SizedBox(height: 20),
            _sectionLabel(
              ArchiveSynthesisCopy.deepDiveNarrativeTitle.toUpperCase(),
            ),
            const SizedBox(height: 8),
            Text(
              _narrative!.narrativeExplanation,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '${ArchiveSynthesisCopy.uncertaintyPrefix}${_narrative!.uncertaintyNote}',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            if (_narrative!.evidenceSynthesis.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final item in _narrative!.evidenceSynthesis)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item.statement,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            _sectionLabel(
              ArchiveSynthesisCopy.deepDiveEvolutionTitle.toUpperCase(),
            ),
            const SizedBox(height: 6),
            Text(
              _narrative!.beliefEvolutionSummary.statement,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              ArchiveSynthesisCopy.synthesisDisclaimer,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _sectionLabel(ArchiveDeepDiveCopy.whySectionTitle.toUpperCase()),
          const SizedBox(height: 8),
          for (final line in dive.why.summaryLines)
            Text(line, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Text(
            '${dive.why.evidenceCount} reflections · '
            '${dive.why.supportingRecordings} supporting recordings',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ArchiveEvidencePanel(
            entries: dive.supportingEntries,
            analyticsContext: 'deep_dive',
            initiallyExpanded: true,
          ),
          const SizedBox(height: 24),
          _sectionLabel(ArchiveDeepDiveCopy.beliefHistoryTitle.toUpperCase()),
          const SizedBox(height: 12),
          _appearanceRow(dive.history.firstAppearance),
          _appearanceRow(dive.history.strongestAppearance),
          _appearanceRow(dive.history.latestAppearance),
          const SizedBox(height: 12),
          _snapshotCard('THEN', dive.history.thenSnapshot),
          const SizedBox(height: 10),
          _snapshotCard('NOW', dive.history.nowSnapshot),
          const SizedBox(height: 24),
          _sectionLabel(ArchiveDeepDiveCopy.counterEvidenceTitle.toUpperCase()),
          const SizedBox(height: 12),
          Text(
            ArchiveDeepDiveCopy.evidenceForLabel,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.primaryIndigo,
            ),
          ),
          const SizedBox(height: 8),
          ...dive.counterEvidence.forExcerpts.map(_excerptTile),
          const SizedBox(height: 16),
          Text(
            ArchiveDeepDiveCopy.evidenceAgainstLabel,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.contradictionRose,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in dive.counterEvidence.againstSummaries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s, style: const TextStyle(height: 1.4)),
            ),
          ...dive.counterEvidence.againstExcerpts.map(_excerptTile),
          const SizedBox(height: 24),
          _sectionLabel(ArchiveDeepDiveCopy.patternExplorerTitle.toUpperCase()),
          const SizedBox(height: 12),
          if (dive.patterns.relatedThemes.isNotEmpty) ...[
            const Text(
              'Related themes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final t in dive.patterns.relatedThemes)
              Text('· $t', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 12),
          ],
          for (final c in dive.patterns.connectedContradictions)
            _connectedCard(c),
          for (final b in dive.patterns.connectedBlindSpots) _connectedCard(b),
          const SizedBox(height: 24),
          _sectionLabel(ArchiveDeepDiveCopy.inquiryTitle.toUpperCase()),
          const SizedBox(height: 12),
          for (final q in dive.inquiryQuestions) ...[
            Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              q.rationale,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _responseControllers[q.id],
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Your reflection…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : () => _saveInquiry(q),
              child: const Text(ArchiveDeepDiveCopy.saveReflection),
            ),
            const SizedBox(height: 20),
          ],
          _sectionLabel(ArchiveDeepDiveCopy.timelineTitle.toUpperCase()),
          const SizedBox(height: 12),
          if (dive.timeline.firstMention != null)
            _timelineEvent(dive.timeline.firstMention!),
          for (final e in dive.timeline.keyRecordings) _timelineEvent(e),
          for (final e in dive.timeline.evolutionEvents) _timelineEvent(e),
          if (dive.timeline.mostRecent != null)
            _timelineEvent(dive.timeline.mostRecent!),
          if (dive.evolutionTimeline.blocks.isNotEmpty) ...[
            const SizedBox(height: 16),
            BeliefEvolutionTimelineWidget(timeline: dive.evolutionTimeline),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Back to Archive'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.8,
        color: AppTheme.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _appearanceRow(ArchiveDeepDiveAppearance a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${a.label}: "${a.beliefText}"'
        '${a.strengthPercent != null ? ' · ${a.strengthPercent}% overlap' : ''}',
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _snapshotCard(String label, ArchiveDeepDiveEvidenceSnapshot snap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"${snap.beliefText}"',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            snap.excerpt,
            style: const TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          if (snap.entryId != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/entry/${snap.entryId}'),
              child: const Text('View recording'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _excerptTile(ArchiveDeepDiveExcerpt e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.dateLabel,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          Text('"${e.quote}"', style: const TextStyle(height: 1.4)),
          TextButton(
            onPressed: () => context.push('/entry/${e.entryId}'),
            child: const Text('View recording'),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(ArchiveDeepDiveConnectedInsight insight) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.kind,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          Text(
            insight.headline,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            insight.detail,
            style: const TextStyle(height: 1.4, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _timelineEvent(ArchiveDeepDiveTimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.circle,
            size: 8,
            color: VoiceMemoryColors.primaryIndigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style: const TextStyle(color: AppTheme.muted, height: 1.4),
                ),
                if (event.entryId != null)
                  TextButton(
                    onPressed: () => context.push('/entry/${event.entryId}'),
                    child: const Text('View recording'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
