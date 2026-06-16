import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/user_facing_date.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../features/signal_archive/signal_archive_coordinator.dart';
import '../features/signal_archive/signal_archive_navigation.dart';
import '../features/signal_archive/signal_archive_snapshot.dart';
import '../features/signal_archive/signal_evidence_model.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../features/prove_enough/prove_enough_evidence_trail_navigation.dart';
import '../widgets/prove_enough/loop_trigger_map_section.dart';

class SignalEvidenceScreen extends StatefulWidget {
  const SignalEvidenceScreen({super.key, this.initialSnapshot});

  /// Test hook — skips async coordinator load when provided.
  @visibleForTesting
  final SignalArchiveSnapshot? initialSnapshot;

  @override
  State<SignalEvidenceScreen> createState() => _SignalEvidenceScreenState();
}

class _SignalEvidenceScreenState extends State<SignalEvidenceScreen> {
  SignalArchiveSnapshot? _snapshot;
  LoopMode? _activeLoop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _snapshot = widget.initialSnapshot;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final snapshot = await SignalArchiveCoordinator.load();
    final activeLoop = await LoopModeCoordinator.loadActive();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _activeLoop = activeLoop;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final snapshot = _snapshot!;
    final trail = snapshot.evidenceTrail;
    final signal = snapshot.selectedSignal;
    final gap = ArchiveResponsiveLayout.gap(context);

    if (signal == null) {
      return Padding(
        padding: ArchiveMobileSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ConsumerUiCopy.signalEvidenceTitle,
              style: ArchiveMobileTypography.archiveSurfaceTitle(context),
            ),
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.signalDetailEmptyBody,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            SizedBox(height: gap),
            FilledButton(
              onPressed: () => context.go('/record'),
              child: Text(ConsumerUiCopy.signalDetailRecordMoment),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Text(
            ConsumerUiCopy.signalEvidenceTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(signal.title, style: ArchiveMobileTypography.listTitle(context)),
          SizedBox(height: gap),
          if (_activeLoop?.isProveEnough == true) ...[
            const LoopTriggerMapSection(),
            OutlinedButton(
              onPressed: () => ProveEnoughEvidenceTrailNavigation.open(context),
              child: const Text('Full evidence trail'),
            ),
            SizedBox(height: gap),
          ],
          if (trail.needsMoreEvidence) ...[
            Container(
              width: double.infinity,
              padding: ArchiveResponsiveLayout.cardInsets(context),
              decoration: VoiceMemoryCards.standard(
                background: const Color(0xFFFFF8F0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ConsumerUiCopy.signalEvidenceNeedsMore,
                    style: ArchiveMobileTypography.responsiveSectionTitle(
                      context,
                    ),
                  ),
                  SizedBox(height: gap),
                  Text(
                    ConsumerUiCopy.signalEvidenceNeedsMoreBody,
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                  SizedBox(height: gap),
                  FilledButton(
                    onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                      context,
                      prompt: trail.nextEvidencePrompt,
                    ),
                    child: Text(
                      ConsumerUiCopy.postSaveInsightRecordNextEvidence,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap),
          ],
          if (trail.supportingItems.isNotEmpty) ...[
            Text(
              ConsumerUiCopy.signalEvidenceSupporting,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...trail.supportingItems.map((item) => _EvidenceTile(item: item)),
            SizedBox(height: gap),
          ],
          if (trail.contradictingItems.isNotEmpty) ...[
            Text(
              ConsumerUiCopy.signalEvidenceContradicting,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...trail.contradictingItems.map(
              (item) => _EvidenceTile(item: item),
            ),
            SizedBox(height: gap),
          ],
          for (final item in trail.items.where(
            (i) => i.relation == SignalEvidenceRelation.unclear,
          )) ...[_EvidenceTile(item: item)],
          if (trail.clarityPrompt.trim().isNotEmpty) ...[
            _infoSection(
              context,
              ConsumerUiCopy.signalEvidenceWhatClearer,
              trail.clarityPrompt,
            ),
          ],
          if (trail.nextEvidencePrompt.trim().isNotEmpty) ...[
            _infoSection(
              context,
              ConsumerUiCopy.signalEvidenceNextPrompt,
              trail.nextEvidencePrompt,
            ),
            SizedBox(height: gap),
            FilledButton(
              onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                context,
                prompt: trail.nextEvidencePrompt,
              ),
              child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _infoSection(BuildContext context, String label, String body) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ArchiveMobileTypography.cardLabel(context)),
            SizedBox(height: gap),
            Text(body, style: ArchiveMobileTypography.explanationBody(context)),
          ],
        ),
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item});

  final SignalEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    final date = formatUserFacingDate(item.date);
    Color relationColor;
    switch (item.relation) {
      case SignalEvidenceRelation.supports:
        relationColor = AppColors.accentPrimary;
      case SignalEvidenceRelation.mightContradict:
        relationColor = const Color(0xFFB45309);
      case SignalEvidenceRelation.unclear:
        relationColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(date, style: ArchiveMobileTypography.cardLabel(context)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: relationColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.relation.label,
                    style: ArchiveMobileTypography.cardLabel(
                      context,
                    ).copyWith(color: relationColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.excerpt,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            if (item.tag.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Chip(
                label: Text(
                  item.tag,
                  style: ArchiveMobileTypography.responsiveBody(context),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
