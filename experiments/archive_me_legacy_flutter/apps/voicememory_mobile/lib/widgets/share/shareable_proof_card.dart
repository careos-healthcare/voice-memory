import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/share/archive_share_actions.dart';
import '../../features/shareable_proof/shareable_proof_analytics.dart';
import '../../features/shareable_proof/shareable_proof_copy.dart';
import '../../features/shareable_proof/shareable_proof_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Generic share card — fixed copy only, explicit tap to share or copy.
class ShareableProofCard extends StatefulWidget {
  const ShareableProofCard({
    super.key,
    required this.result,
    required this.source,
    this.surface = 'record',
    this.onShare,
    this.onCopy,
  });

  const ShareableProofCard.test({
    super.key,
    required this.result,
    required this.source,
    this.surface = 'record',
    this.onShare,
    this.onCopy,
  });

  final ShareableProofResult result;
  final String source;
  final String surface;

  @visibleForTesting
  final Future<void> Function(String text)? onShare;

  @visibleForTesting
  final Future<void> Function(String text)? onCopy;

  @override
  State<ShareableProofCard> createState() => _ShareableProofCardState();
}

class _ShareableProofCardState extends State<ShareableProofCard> {
  var _trackedSeen = false;
  var _selectedTemplate = ShareableProofTemplate.defaultTemplate;
  var _copied = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.result.selectedTemplate;
  }

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ShareableProofAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      result: widget.result,
      template: _selectedTemplate,
    );
  }

  String get _shareText => widget.result.shareTextFor(_selectedTemplate);

  bool get _actionsEnabled =>
      ShareableProofCopy.isSafeShareText(_shareText) &&
      ArchiveShareActions.isShareable(_shareText);

  Future<void> _copy() async {
    if (!_actionsEnabled) return;
    if (widget.onCopy != null) {
      await widget.onCopy!(_shareText);
    } else {
      await ArchiveShareActions.copyShareText(
        context,
        text: _shareText,
        showConfirmation: false,
      );
    }
    if (!mounted) return;
    setState(() => _copied = true);
    ShareableProofAnalytics.copied(
      source: widget.source,
      surface: widget.surface,
      result: widget.result,
      template: _selectedTemplate,
    );
  }

  Future<void> _share() async {
    if (!_actionsEnabled) return;
    if (widget.onShare != null) {
      await widget.onShare!(_shareText);
    } else {
      final outcome = await ArchiveShareActions.shareShareText(
        context,
        text: _shareText,
      );
      if (!mounted) return;
      if (outcome == ArchiveShareOutcome.fallbackCopied) {
        setState(() => _copied = true);
      }
    }
    ShareableProofAnalytics.shared(
      source: widget.source,
      surface: widget.surface,
      result: widget.result,
      template: _selectedTemplate,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) return const SizedBox.shrink();
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final warningStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('shareable_non_private_proof_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F4EF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ShareableProofCopy.title,
            key: const Key('shareable_non_private_proof_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ShareableProofCopy.body,
            key: const Key('shareable_non_private_proof_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _selectedTemplate.text,
            key: const Key('shareable_non_private_proof_template_preview'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ShareableProofCopy.privacyWarning,
            key: const Key('shareable_non_private_proof_privacy_warning'),
            style: warningStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final template in ShareableProofTemplate.values)
                ChoiceChip(
                  key: Key(
                    'shareable_non_private_proof_template_${template.id}',
                  ),
                  label: Text(template.label),
                  selected: _selectedTemplate == template,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _selectedTemplate = template;
                      _copied = false;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('shareable_non_private_proof_copy'),
                  onPressed: _actionsEnabled ? () => _copy() : null,
                  child: Text(_copied ? 'Copied' : 'Copy summary'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('shareable_non_private_proof_share'),
                  onPressed: _actionsEnabled ? () => _share() : null,
                  child: const Text(ShareableProofCopy.shareCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
