import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/pattern_correction/pattern_correction_analytics.dart';
import '../../features/pattern_correction/pattern_correction_copy.dart';
import '../../features/pattern_correction/pattern_correction_engine.dart';
import '../../features/pattern_correction/pattern_correction_model.dart';
import '../../features/pattern_naming/pattern_name_analytics.dart';
import '../../features/pattern_naming/pattern_name_engine.dart';
import '../../features/pattern_naming/pattern_name_store.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../account/beta_feedback_sheet.dart';
import '../archive_controls/archive_moment_actions_sheet.dart';
import '../archive_controls/archive_pattern_exclusion_actions.dart';
import '../patterns/rename_pattern_sheet.dart';
import '../record/correct_transcript_sheet.dart';

/// Bottom sheet for correcting a grounded pattern without losing trust.
class PatternCorrectionSheet extends StatefulWidget {
  const PatternCorrectionSheet({
    super.key,
    required this.contextData,
  });

  final PatternCorrectionContext contextData;

  static Future<void> show(
    BuildContext context, {
    required PatternCorrectionContext contextData,
  }) {
    PatternCorrectionAnalytics.opened(
      source: contextData.source,
      entryCount: contextData.entryCount,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PatternCorrectionSheet(contextData: contextData),
      ),
    );
  }

  @override
  State<PatternCorrectionSheet> createState() => _PatternCorrectionSheetState();
}

class _PatternCorrectionSheetState extends State<PatternCorrectionSheet> {
  PatternCorrectionReason? _selectedReason;

  PatternCorrectionContext get _context => widget.contextData;

  void _selectReason(PatternCorrectionReason reason) {
    PatternCorrectionAnalytics.reasonSelected(
      source: _context.source,
      entryCount: _context.entryCount,
      reason: reason,
    );
    setState(() => _selectedReason = reason);
  }

  Future<void> _handleAction(PatternCorrectionAction action) async {
    PatternCorrectionAnalytics.actionSelected(
      source: _context.source,
      entryCount: _context.entryCount,
      action: action,
    );
    if (!mounted) return;
    Navigator.of(context).pop();

    switch (action) {
      case PatternCorrectionAction.renamePattern:
        await _renamePattern();
      case PatternCorrectionAction.removeFromPattern:
        await _removeFromPattern();
      case PatternCorrectionAction.correctTranscript:
        await _correctTranscript();
      case PatternCorrectionAction.deleteMoment:
        await _deleteMoment();
      case PatternCorrectionAction.privacyCentre:
        if (mounted) context.push('/privacy-trust-centre');
      case PatternCorrectionAction.betaFeedback:
        if (mounted) {
          await BetaFeedbackSheet.show(
            context,
            source: _context.source,
            entryCount: _context.entryCount,
          );
        }
      case PatternCorrectionAction.keepRecording:
        _context.onKeepRecording?.call();
    }
  }

  Future<void> _renamePattern() async {
    final label = _context.patternLabel?.trim();
    if (label == null || label.isEmpty || !mounted) return;

    final patternKey = _context.patternKey?.trim().isNotEmpty == true
        ? _context.patternKey!
        : PatternNameEngine.patternKey(label);
    final saved = await RenamePatternSheet.show(
      context,
      initialName: label,
      onSave: (name) {
        PatternNameStore.setCustomName(patternKey, name);
        PatternNameAnalytics.renamed(
          source: _context.source,
          entryCount: _context.entryCount,
          hasCustomName: true,
        );
      },
    );
    if (saved == true) {
      await _context.onMomentChanged?.call();
    }
  }

  Future<void> _removeFromPattern() async {
    final entryId = _context.latestEntryId;
    final patternKey = _context.patternKey;
    if (entryId == null ||
        entryId.isEmpty ||
        patternKey == null ||
        patternKey.isEmpty ||
        !mounted) {
      return;
    }

    final result = await ArchivePatternExclusionActions.excludeFromPattern(
      context: context,
      entryId: entryId,
      patternKey: patternKey,
      source: _context.source,
    );
    if (result?.excluded == true) {
      await _context.onMomentChanged?.call();
    }
  }

  Future<void> _correctTranscript() async {
    final entryId = _context.latestEntryId;
    if (entryId == null || entryId.isEmpty || !mounted) return;
    if (!AppServices.isInitialized) return;

    final entry = await AppServices.instance.journalStore.getById(entryId);
    if (entry == null || !mounted) return;

    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: _context.source,
      entryCount: _context.entryCount,
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TranscriptCorrectionCopy.savedSuccess)),
      );
      await _context.onMomentChanged?.call();
    }
  }

  Future<void> _deleteMoment() async {
    final entryId = _context.latestEntryId;
    if (entryId == null || entryId.isEmpty || !mounted) return;

    final result = await ArchiveMomentDeleteActions.deleteMoment(
      context: context,
      entryId: entryId,
      source: _context.source,
    );
    if (result?.deleted == true) {
      await _context.onMomentChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final actionStyle = ArchiveMobileTypography.listTitle(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          key: const Key('pattern_correction_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PatternCorrectionCopy.sheetTitle,
              key: const Key('pattern_correction_sheet_title'),
              style: titleStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_selectedReason == null)
              ..._buildReasons(actionStyle)
            else
              ..._buildActions(actionStyle),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReasons(TextStyle actionStyle) {
    return [
      for (final reason in PatternCorrectionEngine.reasons)
        ListTile(
          key: Key('pattern_correction_reason_${PatternCorrectionAnalytics.reasonKey(reason)}'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PatternCorrectionCopy.reasonLabel(reason),
            style: actionStyle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _selectReason(reason),
        ),
    ];
  }

  List<Widget> _buildActions(TextStyle actionStyle) {
    final reason = _selectedReason!;
    final actions = PatternCorrectionEngine.availableActions(
      reason: reason,
      context: _context,
    );

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('pattern_correction_back'),
          onPressed: () => setState(() => _selectedReason = null),
          child: const Text(PatternCorrectionCopy.backToReasons),
        ),
      ),
      Text(
        PatternCorrectionCopy.actionsHeading,
        key: const Key('pattern_correction_actions_heading'),
        style: ArchiveMobileTypography.cardLabel(context).copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      for (final action in actions)
        ListTile(
          key: Key(
            'pattern_correction_action_${PatternCorrectionAnalytics.actionKey(action)}',
          ),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PatternCorrectionCopy.actionLabel(action),
            style: actionStyle,
          ),
          onTap: () => _handleAction(action),
        ),
      if (actions.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            ArchiveControlCopy.patternNeedsMoreEvidenceFallback,
            key: const Key('pattern_correction_no_actions'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ];
  }
}
