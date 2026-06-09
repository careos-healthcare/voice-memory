import 'dart:ui';

import 'package:flutter/material.dart';

import '../../billing/archive_paywall_copy.dart';
import '../../billing/archive_paywall_stats.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';
import 'archive_intelligence_proof_section.dart';

/// Archive intelligence paywall — Variant B production layout.
class ArchivePaywallBody extends StatelessWidget {
  const ArchivePaywallBody({
    super.key,
    required this.stats,
    this.variant,
    this.showPurchaseSection = true,
    this.plansSection,
    this.onPrimaryCta,
    this.onContinueFree,
    this.busy = false,
  });

  final ArchivePaywallStats stats;
  final ArchivePaywallVariant? variant;
  final bool showPurchaseSection;
  final Widget? plansSection;
  final VoidCallback? onPrimaryCta;
  final VoidCallback? onContinueFree;
  final bool busy;

  ArchivePaywallVariant get _variant =>
      variant ?? ArchivePaywallVariantConfig.active;

  @override
  Widget build(BuildContext context) {
    final v = _variant;
    final locked = ArchivePaywallVariantConfig.lockedCards(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchivePaywallVariantConfig.headline(v),
          style: VoiceMemoryTypography.sectionTitleStyle().copyWith(
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          stats.subheadlineFor(v),
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (v == ArchivePaywallVariant.b && stats.hasRichStats) ...[
          const SizedBox(height: 20),
          _heroEvidenceBlock(),
        ],
        if (stats.hasTheoryPreview) ...[
          const SizedBox(height: 20),
          _theoryPreviewCard(),
        ],
        const SizedBox(height: 12),
        _blurredSynthesisBand(),
        const SizedBox(height: 20),
        Text(
          ArchivePaywallCopy.lockedSectionTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(),
        ),
        const SizedBox(height: 10),
        ...locked.map(_lockedCard),
        const SizedBox(height: 22),
        if (ArchivePaywallVariantConfig.useKeyValueSection(v))
          _keyValueSection()
        else if (ArchivePaywallVariantConfig.useSocialProofSection(v))
          _socialProofSection(),
        if (showPurchaseSection) ...[
          const SizedBox(height: 24),
          ArchiveIntelligenceProofSection(
            stats: stats,
            surface: 'subscription',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : onPrimaryCta,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(ArchivePaywallCopy.primaryCta),
          ),
          if (plansSection != null) ...[
            const SizedBox(height: 14),
            plansSection!,
          ],
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: busy ? null : onContinueFree,
              child: const Text(ArchivePaywallCopy.secondaryCta),
            ),
          ),
        ],
      ],
    );
  }

  Widget _heroEvidenceBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        children: [
          Text(
            ArchivePaywallCopy.heroGeneratedFromLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stats.heroRecordingLine(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ArchivePaywallCopy.heroAcrossLabel,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          Text(
            stats.heroSpanLine(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _theoryPreviewCard() {
    final statement = stats.theoryStatement!.trim();
    final confidence = stats.theoryConfidencePercent!;
    final evidence = stats.theoryEvidenceCount!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchivePaywallCopy.theoryPreviewLabel,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$statement"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${ArchivePaywallCopy.basedOnLabel}: $confidence%',
            style: const TextStyle(fontSize: 13, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          Text(
            '${ArchivePaywallCopy.momentCountLabel}: $evidence '
            'recording${evidence == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _blurredSynthesisBand() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: VoiceMemoryColors.surfaceSecondary,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly review · Historian · Milestones',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text(
                  'What changed across your recordings…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: VoiceMemoryColors.surface.withValues(alpha: 0.55),
              ),
            ),
          ),
          const Positioned(
            right: 12,
            top: 12,
            child: Icon(Icons.lock_outline, size: 18, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _lockedCard(ArchivePaywallLockedCard card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyValueSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchivePaywallCopy.keyValueTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          ...ArchivePaywallCopy.keyValueBullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialProofSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchivePaywallCopy.socialProofTitleA,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          ...ArchivePaywallCopy.socialProofBulletsA.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(color: AppTheme.muted)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
