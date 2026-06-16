import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/shareable_archive_proof_model.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Small share card: a preview of the anonymous proof lines plus a copy
/// action and the existing native share. Renders nothing without real proof.
/// Entirely optional and passive — never blocks the core flow, no feed.
class ShareableArchiveProofCard extends StatefulWidget {
  const ShareableArchiveProofCard({
    super.key,
    required this.proof,
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
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in proof.lines)
            Text(
              line,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          Text(
            proof.footer,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
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
