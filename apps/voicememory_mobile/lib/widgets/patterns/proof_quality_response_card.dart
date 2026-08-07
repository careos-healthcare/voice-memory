import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/proof_quality_response/proof_quality_response_analytics.dart';
import '../../features/proof_quality_response/proof_quality_response_copy.dart';
import '../../features/proof_quality_response/proof_quality_response_engine.dart';
import '../../features/proof_quality_response/proof_quality_response_model.dart';
import '../../features/proof_quality_response/proof_quality_response_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Adapts the next proof surface based on beta proof feedback quality.
class ProofQualityResponseCard extends StatefulWidget {
  const ProofQualityResponseCard({
    super.key,
    required this.result,
    required this.source,
    this.store,
    this.onChanged,
    this.skipPrefsLoad = false,
    this.initialRecord,
  });

  const ProofQualityResponseCard.test({
    super.key,
    required this.result,
    required this.source,
    this.store,
    this.onChanged,
    this.initialRecord,
  }) : skipPrefsLoad = true;

  final ProofQualityResponseResult result;
  final String source;
  final ProofQualityResponseStore? store;
  final VoidCallback? onChanged;
  final bool skipPrefsLoad;
  final ProofQualityResponseRecord? initialRecord;

  @override
  State<ProofQualityResponseCard> createState() =>
      _ProofQualityResponseCardState();
}

class _ProofQualityResponseCardState extends State<ProofQualityResponseCard> {
  ProofQualityResponseRecord? _record;
  var _trackedSeen = false;

  @override
  void initState() {
    super.initState();
    _record =
        widget.initialRecord ??
        (widget.skipPrefsLoad
            ? null
            : ProofQualityResponseStore.recordFor(
                surface: widget.result.surface,
                proofKey: widget.result.proofKey,
              ).answered
            ? ProofQualityResponseStore.recordFor(
                surface: widget.result.surface,
                proofKey: widget.result.proofKey,
              )
            : null);
    if (!widget.skipPrefsLoad) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await ProofQualityResponseStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      final loaded = ProofQualityResponseStore.recordFor(
        surface: widget.result.surface,
        proofKey: widget.result.proofKey,
      );
      _record ??= loaded.answered ? loaded : null;
    });
  }

  void _trackSeenOnce() {
    if (_trackedSeen || _record != null) return;
    _trackedSeen = true;
    ProofQualityResponseAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  Future<void> _selectStillTooVague() async {
    if (_record != null) return;
    await ProofQualityResponseEngine.applyStillTooVague(
      result: widget.result,
      source: widget.source,
      store: widget.store,
    );
    ProofQualityResponseAnalytics.answered(
      source: widget.source,
      result: widget.result,
      answerType: ProofQualityResponseAnswerType.stillTooVague,
    );
    if (!mounted) return;
    setState(() {
      _record = ProofQualityResponseRecord(
        answerType: ProofQualityResponseAnswerType.stillTooVague,
        feedbackState: widget.result.feedbackState,
        proofKey: widget.result.proofKey,
        surface: widget.result.surface,
        entryCount: widget.result.entryCount,
        answeredAt: DateTime.now().toUtc(),
        stillTooVague: true,
      );
    });
    widget.onChanged?.call();
  }

  Future<void> _selectAlreadyKnew(ProofQualityAlreadyKnewAnswer answer) async {
    if (_record != null) return;
    final answerType = switch (answer) {
      ProofQualityAlreadyKnewAnswer.cameBackStronger =>
        ProofQualityResponseAnswerType.cameBackStronger,
      ProofQualityAlreadyKnewAnswer.feltLighter =>
        ProofQualityResponseAnswerType.feltLighter,
      ProofQualityAlreadyKnewAnswer.somethingHelped =>
        ProofQualityResponseAnswerType.somethingHelped,
      ProofQualityAlreadyKnewAnswer.noChange =>
        ProofQualityResponseAnswerType.noChange,
    };
    final store = widget.store ?? ProofQualityResponseStore.instance();
    await store.saveAnswer(
      surface: widget.result.surface,
      proofKey: widget.result.proofKey,
      answerType: answerType,
      feedbackState: widget.result.feedbackState,
      entryCount: widget.result.entryCount,
    );
    ProofQualityResponseAnalytics.answered(
      source: widget.source,
      result: widget.result,
      answerType: answerType,
    );
    if (!mounted) return;
    setState(() {
      _record = ProofQualityResponseRecord(
        answerType: answerType,
        feedbackState: widget.result.feedbackState,
        proofKey: widget.result.proofKey,
        surface: widget.result.surface,
        entryCount: widget.result.entryCount,
        answeredAt: DateTime.now().toUtc(),
      );
    });
    widget.onChanged?.call();
    await ProofQualityResponseEngine.syncAlreadyKnewFromAction(
      result: widget.result,
      answer: answer,
      source: widget.source,
    );
  }

  Future<void> _selectNotRelevant(ProofQualityNotRelevantAction action) async {
    if (_record != null) return;
    final answerType = switch (action) {
      ProofQualityNotRelevantAction.keepAsBackground =>
        ProofQualityResponseAnswerType.keepAsBackground,
      ProofQualityNotRelevantAction.watchLightly =>
        ProofQualityResponseAnswerType.watchLightly,
      ProofQualityNotRelevantAction.relevantAgain =>
        ProofQualityResponseAnswerType.relevantAgain,
    };
    final store = widget.store ?? ProofQualityResponseStore.instance();
    await store.saveAnswer(
      surface: widget.result.surface,
      proofKey: widget.result.proofKey,
      answerType: answerType,
      feedbackState: widget.result.feedbackState,
      entryCount: widget.result.entryCount,
    );
    ProofQualityResponseAnalytics.answered(
      source: widget.source,
      result: widget.result,
      answerType: answerType,
    );
    if (!mounted) return;
    setState(() {
      _record = ProofQualityResponseRecord(
        answerType: answerType,
        feedbackState: widget.result.feedbackState,
        proofKey: widget.result.proofKey,
        surface: widget.result.surface,
        entryCount: widget.result.entryCount,
        answeredAt: DateTime.now().toUtc(),
      );
    });
    widget.onChanged?.call();
    await ProofQualityResponseEngine.syncNotRelevantFromAction(
      result: widget.result,
      action: action,
      source: widget.source,
    );
  }

  Key _actionKey(String suffix) => Key('proof_quality_response_$suffix');

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final record = _record;

    if (record != null && record.answerType != null) {
      final followUp = ProofQualityResponseEngine.followUpFor(
        result: widget.result,
        record: record,
      );
      return Container(
        key: const Key('proof_quality_response_answered_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFF8FAF8),
        ),
        child: Text(
          followUp,
          key: Key(
            'proof_quality_response_follow_up_${record.answerType!.analyticsValue}',
          ),
          style: bodyStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    return Container(
      key: const Key('proof_quality_response_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('proof_quality_response_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('proof_quality_response_body'),
            style: bodyStyle,
          ),
          if (widget.result.hasFreshReturn) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.returnedAfterCorrectionLine,
              key: const Key(
                'proof_quality_response_returned_after_correction',
              ),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
          if (widget.result.feedbackState ==
              ProofQualityFeedbackState.tooVague) ...[
            const SizedBox(height: AppSpacing.sm),
            if (widget.result.usesFallbackEvidenceLine)
              Text(
                ProofQualityResponseCopy.tooVagueFallback,
                key: const Key('proof_quality_response_fallback_anchor'),
                style: bodyStyle.copyWith(color: AppColors.textPrimary),
              )
            else
              for (final anchor in widget.result.evidenceAnchors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    anchor,
                    key: Key(
                      'proof_quality_response_anchor_${anchor.hashCode}',
                    ),
                    style: bodyStyle.copyWith(color: AppColors.textPrimary),
                  ),
                ),
          ],
          if (widget.result.rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final row in widget.result.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  row,
                  key: Key('proof_quality_response_row_${row.hashCode}'),
                  style: bodyStyle,
                ),
              ),
          ],
          if (widget.result.deltaLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.deltaLine!,
              key: const Key('proof_quality_response_delta_line'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.footer,
            key: const Key('proof_quality_response_footer'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return switch (widget.result.feedbackState) {
      ProofQualityFeedbackState.tooVague => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          TextButton(
            key: _actionKey('still_too_vague'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 13),
            ),
            onPressed: () => unawaited(_selectStillTooVague()),
            child: const Text(ProofQualityResponseCopy.stillTooVagueLabel),
          ),
        ],
      ),
      ProofQualityFeedbackState.alreadyKnewThis => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final answer in ProofQualityAlreadyKnewAnswer.values)
            TextButton(
              key: _actionKey(answer.storageValue),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: () => unawaited(_selectAlreadyKnew(answer)),
              child: Text(
                ProofQualityResponseCopy.alreadyKnewAnswerLabel(answer),
              ),
            ),
        ],
      ),
      ProofQualityFeedbackState.notRelevant => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final action in ProofQualityNotRelevantAction.values)
            TextButton(
              key: _actionKey(action.storageValue),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: () => unawaited(_selectNotRelevant(action)),
              child: Text(
                ProofQualityResponseCopy.notRelevantActionLabel(action),
              ),
            ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
