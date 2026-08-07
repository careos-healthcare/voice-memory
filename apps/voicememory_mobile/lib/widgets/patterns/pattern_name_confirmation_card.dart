import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pattern_naming/pattern_name_analytics.dart';
import '../../features/pattern_naming/pattern_name_copy.dart';
import '../../features/pattern_naming/pattern_name_model.dart';
import '../../features/pattern_naming/pattern_name_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'rename_pattern_sheet.dart';

/// Compact confirmation for a grounded pattern label on Patterns / belief surfaces.
class PatternNameConfirmationCard extends StatefulWidget {
  const PatternNameConfirmationCard({
    super.key,
    required this.prompt,
    required this.source,
    required this.entryCount,
    required this.onChanged,
  });

  final PatternNamePrompt prompt;
  final String source;
  final int entryCount;
  final VoidCallback onChanged;

  @override
  State<PatternNameConfirmationCard> createState() =>
      _PatternNameConfirmationCardState();
}

class _PatternNameConfirmationCardState
    extends State<PatternNameConfirmationCard> {
  String? _statusMessage;
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    PatternNameAnalytics.promptSeen(
      source: widget.source,
      entryCount: widget.entryCount,
      hasCustomName: PatternNameStore.hasCustomName(widget.prompt.patternKey),
    );
  }

  void _confirmYes() {
    PatternNameStore.confirm(widget.prompt.patternKey);
    PatternNameAnalytics.confirmed(
      source: widget.source,
      entryCount: widget.entryCount,
      hasCustomName: false,
    );
    widget.onChanged();
  }

  Future<void> _openRename() async {
    final saved = await RenamePatternSheet.show(
      context,
      initialName: widget.prompt.displayLabel,
      onSave: (name) {
        PatternNameStore.setCustomName(widget.prompt.patternKey, name);
        PatternNameAnalytics.renamed(
          source: widget.source,
          entryCount: widget.entryCount,
          hasCustomName: true,
        );
      },
    );
    if (!mounted || saved != true) return;
    setState(() => _statusMessage = PatternNameCopy.savedMessage);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);

    if (_statusMessage != null) {
      return Container(
        key: const Key('pattern_name_saved_message'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFF8FAF8),
        ),
        child: Text(_statusMessage!, style: bodyStyle),
      );
    }

    if (PatternNameStore.isResolved(widget.prompt.patternKey)) {
      return const SizedBox.shrink();
    }

    final labelStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);

    return Container(
      key: const Key('pattern_name_confirmation_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PatternNameCopy.prompt,
            key: const Key('pattern_name_prompt'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PatternNameCopy.currentLabelLine(widget.prompt.displayLabel),
            key: const Key('pattern_name_current_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pattern_name_yes_button'),
                  onPressed: _confirmYes,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                  ),
                  child: const Text(PatternNameCopy.yesCta),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('pattern_name_rename_button'),
                  onPressed: _openRename,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(PatternNameCopy.renameCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
