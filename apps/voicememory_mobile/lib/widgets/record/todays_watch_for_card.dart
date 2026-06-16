import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/screenshot_mode.dart';
import '../../features/activation/activation_tracker.dart';
import '../../features/tomorrow_return/return_capture_engine.dart';
import '../../features/tomorrow_return/return_capture_model.dart';
import '../../features/tomorrow_return/return_capture_store.dart';
import '../../features/tomorrow_return/watch_for_coordinator.dart';
import '../../features/tomorrow_return/watch_for_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shown at the top of Record when a pending watch-for is due today.
class TodaysWatchForCard extends StatefulWidget {
  const TodaysWatchForCard({
    super.key,
    required this.pending,
    this.persistSelection,
    this.loadSelection,
    this.trackActivation = true,
    this.onRecord,
    this.onSkip,
    this.onQuickAnswerSelected,
  });

  final WatchForItem pending;

  /// Test hook; defaults to [ReturnCaptureStore.instance].
  final Future<void> Function(ReturnCaptureSelection selection)?
  persistSelection;

  final Future<ReturnCaptureSelection?> Function()? loadSelection;

  final bool trackActivation;

  final VoidCallback? onRecord;

  /// Test hook; defaults to [WatchForCoordinator.skipPendingForToday].
  final Future<void> Function()? onSkip;

  /// Test hook after a quick answer is saved.
  final Future<void> Function(ReturnQuickAnswer answer)? onQuickAnswerSelected;

  @override
  State<TodaysWatchForCard> createState() => _TodaysWatchForCardState();
}

class _TodaysWatchForCardState extends State<TodaysWatchForCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  final _captureEngine = const ReturnCaptureEngine();
  String? _selectedQuickAnswerId;
  bool _loadingSelection = true;

  @override
  void initState() {
    super.initState();
    if (widget.loadSelection != null) {
      _loadingSelection = false;
      unawaited(_loadSelection());
    } else {
      unawaited(_loadSelection());
    }
  }

  Future<ReturnCaptureSelection?> _readSelection() async {
    final load =
        widget.loadSelection ??
        () => ReturnCaptureStore.instance().loadLatest();
    return load();
  }

  Future<void> _writeSelection(ReturnCaptureSelection selection) async {
    final save =
        widget.persistSelection ??
        (value) => ReturnCaptureStore.instance().saveSelection(value);
    await save(selection);
  }

  Future<void> _loadSelection() async {
    final selection = await _readSelection();
    if (!mounted) return;
    setState(() {
      _loadingSelection = false;
      if (selection != null && selection.watchForId == widget.pending.id) {
        _selectedQuickAnswerId = selection.selectedQuickAnswerId;
      } else if (ScreenshotMode.enabled &&
          ScreenshotMode.returnCaptureSelection != null) {
        _selectedQuickAnswerId =
            ScreenshotMode.returnCaptureSelection!.selectedQuickAnswerId;
      }
    });
  }

  ReturnCaptureModel get _capture =>
      _captureEngine.build(pending: widget.pending);

  ReturnQuickAnswer? get _selectedAnswer {
    final id = _selectedQuickAnswerId;
    if (id == null) return null;
    return _captureEngine.quickAnswerById(id);
  }

  Future<void> _onQuickAnswerTap(ReturnQuickAnswer answer) async {
    if (_selectedQuickAnswerId == answer.id) return;
    setState(() => _selectedQuickAnswerId = answer.id);
    await _writeSelection(
      ReturnCaptureSelection(
        watchForId: widget.pending.id,
        selectedQuickAnswerId: answer.id,
        comparisonHint: answer.comparisonHint,
        createdAt: DateTime.now(),
      ),
    );
    if (widget.trackActivation) {
      await ActivationTracker.trackReturnCaptureQuickAnswerSelected(
        quickAnswerId: answer.id,
        comparisonHint: answer.comparisonHint,
      );
    }
    if (widget.onQuickAnswerSelected != null) {
      await widget.onQuickAnswerSelected!(answer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedAnswer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.todaysWatchForTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.pending.displaySpecificPrompt,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.4,
            ),
          ),
          if (widget.pending.situationHint != null &&
              widget.pending.situationHint!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.pending.situationHint!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 14, height: 1.4),
            ),
          ],
          if (widget.pending.checkInQuestion != null &&
              widget.pending.checkInQuestion!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.todaysWatchForCheckInLabel,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pending.checkInQuestion!,
              style: VoiceMemoryTypography.bodyStyle().copyWith(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!_loadingSelection) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _capture.quickAnswers
                  .map((answer) => _quickAnswerChip(answer))
                  .toList(),
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              selected.followUpPrompt,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: widget.onRecord,
              child: const Text(ConsumerUiCopy.todaysWatchForRecordCta),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () async {
                if (widget.onSkip != null) {
                  await widget.onSkip!();
                  return;
                }
                await WatchForCoordinator.skipPendingForToday();
              },
              child: const Text(ConsumerUiCopy.todaysWatchForSkipCta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAnswerChip(ReturnQuickAnswer answer) {
    final selected = _selectedQuickAnswerId == answer.id;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _onQuickAnswerTap(answer),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accentPrimary : _warmBorder,
            ),
          ),
          child: Text(
            answer.label,
            style:
                VoiceMemoryTypography.bodyStyle(
                  color: selected
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                ).copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
          ),
        ),
      ),
    );
  }
}
