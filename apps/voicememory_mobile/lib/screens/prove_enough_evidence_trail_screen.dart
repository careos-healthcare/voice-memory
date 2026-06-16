import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/revenuecat_service.dart';
import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../design/user_facing_date.dart';
import '../features/prove_enough/prove_enough_evidence_trail_coordinator.dart';
import '../features/prove_enough/prove_enough_evidence_trail_model.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
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
  final PremiumEntitlements? initialEntitlements;

  @visibleForTesting
  final VoidCallback? onSeePro;

  @override
  State<ProveEnoughEvidenceTrailScreen> createState() =>
      _ProveEnoughEvidenceTrailScreenState();
}

class _ProveEnoughEvidenceTrailScreenState
    extends State<ProveEnoughEvidenceTrailScreen> {
  ProveEnoughEvidenceTrail? _trail;
  PremiumEntitlements? _entitlements;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrail != null) {
      _trail = widget.initialTrail;
      _entitlements = widget.initialEntitlements;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final trail = await ProveEnoughEvidenceTrailCoordinator.load();
    PremiumEntitlements? entitlements = widget.initialEntitlements;
    if (AppServices.isInitialized) {
      entitlements = await AppServices.instance.billing.loadEntitlements();
    }
    if (!mounted) return;
    setState(() {
      _trail = trail;
      _entitlements = entitlements;
      _loading = false;
    });
  }

  bool get _isPro => _entitlements?.isPro == true;

  void _openPro() {
    if (widget.onSeePro != null) {
      widget.onSeePro!();
      return;
    }
    if (RevenueCatService.instance.isConfigured) {
      context.push('/subscription');
    }
  }

  bool get _billingReady =>
      widget.onSeePro != null || RevenueCatService.instance.isConfigured;

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
              moments: _isPro ? trail.supportingMoments : trail.previewMoments,
            ),
            if (!_isPro && trail.hasExtendedContent) ...[
              const SizedBox(height: AppSpacing.md),
              _LockedTrailCard(onSeePro: _openPro, billingReady: _billingReady),
            ],
            if (_isPro) ...[
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
          ],
          const SizedBox(height: AppSpacing.lg),
          ProveEnoughPatternReportExportButton(
            isPro: _isPro,
            onSeePro: _billingReady ? _openPro : null,
          ),
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

class _LockedTrailCard extends StatelessWidget {
  const _LockedTrailCard({required this.onSeePro, required this.billingReady});

  final VoidCallback onSeePro;
  final bool billingReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('prove_enough_trail_locked_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.accentLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProveEnoughEvidenceTrail.lockedTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProveEnoughEvidenceTrail.lockedBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('prove_enough_trail_see_pro_cta'),
            onPressed: billingReady ? onSeePro : null,
            child: const Text(ProveEnoughEvidenceTrail.lockedCta),
          ),
        ],
      ),
    );
  }
}
