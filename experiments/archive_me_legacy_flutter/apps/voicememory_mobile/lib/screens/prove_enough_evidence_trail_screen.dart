import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../design/user_facing_date.dart';
import '../features/prove_enough/prove_enough_evidence_trail_coordinator.dart';
import '../features/prove_enough/prove_enough_evidence_trail_model.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/prove_enough/prove_enough_pattern_report_export_button.dart';

/// Pro full evidence trail for the prove_enough loop — free users get preview.
class ProveEnoughEvidenceTrailScreen extends StatefulWidget {
  const ProveEnoughEvidenceTrailScreen({
    super.key,
    this.initialTrail,
    this.initialEntitlements,
    this.onSeePro,
  });

  @visibleForTesting
  final ProveEnoughEvidenceTrail? initialTrail;

  @visibleForTesting
  final SubscriptionState? initialEntitlements;

  @visibleForTesting
  final VoidCallback? onSeePro;

  @override
  State<ProveEnoughEvidenceTrailScreen> createState() =>
      _ProveEnoughEvidenceTrailScreenState();
}

class _ProveEnoughEvidenceTrailScreenState
    extends State<ProveEnoughEvidenceTrailScreen> {
  ProveEnoughEvidenceTrail? _trail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrail != null) {
      _trail = widget.initialTrail;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final trail = await ProveEnoughEvidenceTrailCoordinator.load();
    if (!mounted) return;
    setState(() {
      _trail = trail;
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
    final trail = _trail!;
    return RefreshIndicator(
      onRefresh: widget.initialTrail == null ? _load : () async {},
      child: ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Text(
            ProveEnoughEvidenceTrail.screenTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ProveEnoughEvidenceTrail.screenSubtitle,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!trail.hasPreview && !trail.hasExtendedContent)
            Text(
              'Save a few proving moments to build your evidence trail.',
              style: ArchiveMobileTypography.explanationBody(
                context,
              ).copyWith(color: AppColors.textSecondary),
            )
          else ...[
            _section(
              context,
              title: ProveEnoughEvidenceTrail.confirmedSectionTitle,
              moments: trail.supportingMoments,
            ),
            _gatedSection(
              context,
              title: ProveEnoughEvidenceTrail.challengedSectionTitle,
              moments: trail.contradictionMoments,
            ),
            _gatedSection(
              context,
              title: ProveEnoughEvidenceTrail.restGuiltSectionTitle,
              moments: trail.restGuiltMoments,
            ),
            _gatedSection(
              context,
              title: ProveEnoughEvidenceTrail.choiceSectionTitle,
              moments: trail.choiceMoments,
            ),
            if (trail.triggerSummary.trim().isNotEmpty)
              _textSection(
                context,
                title: ProveEnoughEvidenceTrail.triggerSectionTitle,
                body: trail.triggerSummary,
              ),
            if (trail.whatChanged.trim().isNotEmpty)
              _textSection(
                context,
                title: ProveEnoughEvidenceTrail.changedSectionTitle,
                body: trail.whatChanged,
              ),
            if (trail.latestMission?.trim().isNotEmpty == true)
              _textSection(
                context,
                title: 'Latest mission',
                body: trail.latestMission!,
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const ProveEnoughPatternReportExportButton(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<ProveEnoughEvidenceMoment> moments,
  }) {
    if (moments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        ...moments.map((moment) => _MomentTile(moment: moment)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _gatedSection(
    BuildContext context, {
    required String title,
    required List<ProveEnoughEvidenceMoment> moments,
  }) {
    return _section(context, title: title, moments: moments);
  }

  Widget _textSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ArchiveMobileTypography.cardLabel(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: ArchiveMobileTypography.explanationBody(context)),
          ],
        ),
      ),
    );
  }
}

class _MomentTile extends StatelessWidget {
  const _MomentTile({required this.moment});

  final ProveEnoughEvidenceMoment moment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFF8FBFF),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatUserFacingDate(moment.createdAt),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              moment.excerpt,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
        ),
      ),
    );
  }
}
