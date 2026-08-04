import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../features/archive_analyst/archive_analyst_copy.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../features/archive_analyst/archive_analyst_engine.dart';
import '../features/archive_analyst/archive_analyst_gate.dart';
import '../features/archive_analyst/archive_analyst_models.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/audio_digest_player_widget.dart';
import '../widgets/pushed_screen_shell.dart';

/// Periodic archive analyst report — evidence synthesis only.
class ArchiveAnalystScreen extends StatefulWidget {
  const ArchiveAnalystScreen({super.key});

  @override
  State<ArchiveAnalystScreen> createState() => _ArchiveAnalystScreenState();
}

class _ArchiveAnalystScreenState extends State<ArchiveAnalystScreen> {
  ArchiveAnalystReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AppServices.instance.journal.loadAll();
    final state = buildArchiveStateObjectV3(entries: entries);
    final report = await const ArchiveAnalystEngine().build(
      entries: entries,
      state: state,
      evolutionService: AppServices.instance.beliefEvolution,
    );
    if (mounted) {
      setState(() {
        _report = report;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PushedScreenShell(
        title: ArchiveAnalystCopy.screenTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final report = _report!;
    if (!report.hasReport) {
      final remaining = ArchiveAnalystGate.reflectionsUntilLevel1(
        report.eligibleReflectionCount,
      );
      return PushedScreenShell(
        title: ArchiveAnalystCopy.screenTitle,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ArchiveAnalystCopy.insufficientTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                ArchiveAnalystCopy.insufficientBody(
                  report.eligibleReflectionCount,
                  remaining,
                ),
                style: const TextStyle(color: AppTheme.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text('Record another moment'),
              ),
            ],
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: report.level.reportTitle,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              ArchiveAnalystCopy.historianLead,
              style: const TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ArchiveAnalystCopy.challengeableNote,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            AudioDigestPlayerWidget(
              title: 'Archive Audio Digest',
              narrative: const ArchiveAnalystEngine().buildAudioDigest(report),
            ),
            const SizedBox(height: 24),
            _sectionHeader(ArchiveAnalystCopy.evidenceSummaryTitle),
            _summaryCard(report),
            const SizedBox(height: 24),
            _sectionHeader(ArchiveAnalystCopy.currentBeliefsTitle),
            ...report.currentBeliefs.map(_beliefRow),
            const SizedBox(height: 24),
            if (report.emergingBeliefs.isNotEmpty) ...[
              _sectionHeader(ArchiveAnalystCopy.emergingTitle),
              ...report.emergingBeliefs.map(_trendCard),
              const SizedBox(height: 24),
            ],
            if (report.fadingBeliefs.isNotEmpty) ...[
              _sectionHeader(ArchiveAnalystCopy.fadingTitle),
              ...report.fadingBeliefs.map(_trendCard),
              const SizedBox(height: 24),
            ],
            if (report.contradictions.isNotEmpty) ...[
              _sectionHeader(ArchiveAnalystCopy.contradictionsTitle),
              ...report.contradictions.map(_contradictionTile),
              const SizedBox(height: 24),
            ],
            if (report.blindSpots.isNotEmpty) ...[
              _sectionHeader(ArchiveAnalystCopy.blindSpotsTitle),
              ...report.blindSpots.map(_blindSpotTile),
              const SizedBox(height: 24),
            ],
            _sectionHeader(ArchiveAnalystCopy.competingTitle),
            Text(
              ArchiveAnalystCopy.competingLead,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...report.competingBeliefs.map(_competingRow),
            const SizedBox(height: 24),
            _sectionHeader(ArchiveAnalystCopy.debateTitle),
            Text(
              ArchiveAnalystCopy.debateLead,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...report.debates.map(_debateCard),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: VoiceMemoryTypography.sectionLabelStyle(
          accent: VoiceMemoryColors.primaryIndigo,
        ),
      ),
    );
  }

  Widget _summaryCard(ArchiveAnalystReport report) {
    final s = report.evidenceSummary;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s.eligibleReflectionCount} eligible saved moments'),
          Text('Span: ${s.dateSpanLabel}'),
          Text('${s.uniqueBeliefCandidates} belief candidates weighed'),
          Text(
            '${s.contradictionCount} contradictions · ${s.blindSpotCount} blind spots',
          ),
        ],
      ),
    );
  }

  Widget _beliefRow(ArchiveAnalystBeliefRow b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (b.isPrimary)
              const Text(
                ArchiveAnalystCopy.primaryExplanation,
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            Text(
              '"${b.statement}"',
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('Confidence: ${b.confidencePercent}%'),
            Text('Evidence: ${b.evidenceCount} recordings'),
            Text('Counter-evidence: ${b.counterEvidenceCount} recordings'),
            if (b.lastUpdated != null)
              Text(
                'Last updated: ${formatUserFacingDate(b.lastUpdated!)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(ArchiveAnalystTrendBelief t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${t.statement}"',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(t.trendLabel, style: const TextStyle(color: AppTheme.muted)),
            Text('Confidence: ${t.confidencePercent}%'),
          ],
        ),
      ),
    );
  }

  Widget _competingRow(ArchiveAnalystCompetingBelief c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '${c.confidencePercent}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: c.isPrimary
                    ? VoiceMemoryColors.primaryIndigo
                    : AppTheme.foreground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              c.isPrimary ? '${c.statement} (primary)' : c.statement,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debateCard(ArchiveAnalystDebate d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${d.beliefStatement}"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Confidence: ${d.confidencePercent}%'),
            const SizedBox(height: 12),
            Text(
              ArchiveAnalystCopy.evidenceFor,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text('${d.evidenceForCount} recordings'),
            ...d.supportingExcerpts.map(_excerpt),
            const SizedBox(height: 12),
            Text(
              ArchiveAnalystCopy.evidenceAgainst,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text('${d.evidenceAgainstCount} items'),
            ...d.counterExcerpts.map(_excerpt),
            for (final n in d.timelineNotes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  n,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _excerpt(ArchiveAnalystExcerpt e) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.dateLabel,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          Text(
            '"${e.quote}"',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          TextButton(
            onPressed: () => context.push('/entry/${e.entryId}'),
            child: const Text('View recording'),
          ),
        ],
      ),
    );
  }

  Widget _contradictionTile(ArchiveV1Contradiction c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '· ${c.youSay} — ${c.but}',
        style: const TextStyle(color: AppTheme.muted, height: 1.4),
      ),
    );
  }

  Widget _blindSpotTile(ArchiveV1BlindSpot b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '· ${b.headline}: ${b.observation}',
        style: const TextStyle(height: 1.4),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: child,
    );
  }
}
