import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Small share card: preview of anonymous proof lines plus copy/share actions.
/// Renders nothing without real proof. Optional and passive — never blocks flow.
class ShareableArchiveProofCard extends StatefulWidget {
  const ShareableArchiveProofCard({
    required this.proof, super.key,
    this.onShare,
    this.onCopy,
  });

  final ShareableArchiveProof proof;

  /// Test hook; production uses [ArchiveShareActions].
  @visibleForTesting
  final Future<void> Function(String text)? onShare;

  @visibleForTesting
  final Future<void> Function(String text)? onCopy;

  @override
  State<ShareableArchiveProofCard> createState() =>
      _ShareableArchiveProofCardState();
}

class _ShareableArchiveProofCardState extends State<ShareableArchiveProofCard> {
  bool _copied = false;

  String get _shareText => widget.proof.shareText;

  bool get _actionsEnabled => ArchiveShareActions.isShareable(_shareText);

  Future<void> _copy() async {
    if (!_actionsEnabled) return;
    if (widget.onCopy != null) {
      await widget.onCopy!(_shareText);
      if (!mounted) return;
      setState(() => _copied = true);
      return;
    }
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: _shareText,
      showConfirmation: false,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied) {
      setState(() => _copied = true);
    }
  }

  Future<void> _share() async {
    if (!_actionsEnabled) return;
    if (widget.onShare != null) {
      await widget.onShare!(_shareText);
      return;
    }
    final outcome = await ArchiveShareActions.shareShareText(
      context,
      text: _shareText,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.fallbackCopied) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proof = widget.proof;
    if (!proof.hasProof) return const SizedBox.shrink();

    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('shareable_archive_proof_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F4EF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proof.title,
            key: const Key('shareable_proof_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (proof.subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              proof.subtitle,
              key: const Key('shareable_proof_subtitle'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < proof.lines.length; i++)
            Text(
              proof.lines[i],
              key: Key('shareable_proof_line_$i'),
              style: bodyStyle,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ShareableArchiveProof.privacyFooter,
            key: const Key('shareable_proof_privacy_footer'),
            style: footnoteStyle,
          ),
          Text(
            ShareableArchiveProof.productLine,
            key: const Key('shareable_proof_product_line'),
            style: footnoteStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                key: const Key('shareable_proof_copy'),
                onPressed: _actionsEnabled ? _copy : null,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(
                  _copied
                      ? ShareableArchiveProof.copiedLabel
                      : ShareableArchiveProof.copyLabel,
                ),
              ),
              TextButton.icon(
                key: const Key('shareable_proof_share'),
                onPressed: _actionsEnabled ? _share : null,
                icon: const Icon(Icons.ios_share_outlined, size: 16),
                label: const Text(ShareableArchiveProof.shareLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}