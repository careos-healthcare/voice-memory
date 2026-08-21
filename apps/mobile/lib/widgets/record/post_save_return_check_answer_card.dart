import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_check_answer_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_check_answer_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Lightweight post-save return check question — no extra primary CTAs.
class PostSaveReturnCheckAnswerCard extends StatefulWidget {
  const PostSaveReturnCheckAnswerCard({
    required this.answer, super.key,
    this.store,
    this.skipPrefsLoad = false,
    this.onChanged,
  });

  const PostSaveReturnCheckAnswerCard.test({
    required this.answer, super.key,
    this.store,
    this.onChanged,
  }) : skipPrefsLoad = true;

  final PostSaveReturnCheckAnswer answer;
  final RepeatReturnCheckStore? store;
  final bool skipPrefsLoad;
  final VoidCallback? onChanged;

  @override
  State<PostSaveReturnCheckAnswerCard> createState() =>
      _PostSaveReturnCheckAnswerCardState();
}

class _PostSaveReturnCheckAnswerCardState
    extends State<PostSaveReturnCheckAnswerCard> {
  RepeatReturnCheckStore? _store;
  bool _saving = false;
  bool _answered = false;

  RepeatReturnCheckStore get _resolvedStore =>
      _store ??= widget.store ?? RepeatReturnCheckStore.instance();

  bool get _hasStoredAnswer =>
      _resolvedStore.recordForEntry(widget.answer.entryId)?.choice != null;

  @override
  void initState() {
    super.initState();
    _answered = _hasStoredAnswer;
    if (!_answered) {
      PostSaveReturnCheckAnswerAnalytics.seen(
        entryCount: widget.answer.entryCount,
        hasPhrase: widget.answer.hasPhrase,
        hasConfirmedRepeat: widget.answer.hasConfirmedRepeat,
      );
    }
  }

  Future<void> _select(PostSaveReturnCheckAnswerChoice choice) async {
    if (_saving || _answered || _hasStoredAnswer) return;
    _saving = true;
    PostSaveReturnCheckAnswerAnalytics.tapped(
      entryCount: widget.answer.entryCount,
      answer: choice,
      hasPhrase: widget.answer.hasPhrase,
      hasConfirmedRepeat: widget.answer.hasConfirmedRepeat,
    );
    unawaited(
      _resolvedStore.saveChoice(
        entryId: widget.answer.entryId,
        choice: choice.storageChoice,
        entryCountAtCapture: widget.answer.entryCount,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _answered = true;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_answered || _hasStoredAnswer) {
      return const SizedBox.shrink(
        key: Key('post_save_return_check_answer_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('post_save_return_check_answer_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.answer.label,
            key: const Key('post_save_return_check_answer_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.answer.title,
            key: const Key('post_save_return_check_answer_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.answer.body,
            key: const Key('post_save_return_check_answer_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final choice in PostSaveReturnCheckAnswerChoice.values)
                OutlinedButton(
                  key: Key('post_save_return_check_answer_${choice.name}'),
                  onPressed: _saving ? null : () => _select(choice),
                  child: Text(choice.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.answer.footer,
            key: const Key('post_save_return_check_answer_footer'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}