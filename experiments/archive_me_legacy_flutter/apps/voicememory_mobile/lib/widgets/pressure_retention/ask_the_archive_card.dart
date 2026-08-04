import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/archive_reflection_engine.dart';
import '../../features/pressure_retention/archive_reflection_model.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Focused "Ask the archive" card — four fixed, evidence-based questions only.
///
/// This is deliberately NOT a general chatbot. Answers come from local saved
/// pressure data, and the archive says when it lacks enough evidence.
class AskTheArchiveCard extends StatefulWidget {
  const AskTheArchiveCard({
    super.key,
    required this.records,
    this.engine = const ArchiveReflectionEngine(),
    this.locked = false,
    this.onUnlock,
  });

  final List<PressureCheckInRecord> records;
  final ArchiveReflectionEngine engine;

  /// When true (free users), the four questions are shown but disabled —
  /// tapping any of them opens the Pro upgrade flow via [onUnlock].
  final bool locked;
  final VoidCallback? onUnlock;

  static const title = 'Ask the archive';
  static const subtitle = 'Evidence-based answers from your own saved moments.';
  static const lockedSubtitle =
      'Ask your archive what this pressure is trying to prove — with Pro.';

  @override
  State<AskTheArchiveCard> createState() => _AskTheArchiveCardState();
}

class _AskTheArchiveCardState extends State<AskTheArchiveCard> {
  String? _selectedQuestionId;
  ArchiveReflectionAnswer? _answer;

  void _ask(ArchiveReflectionQuestion question) {
    if (widget.locked) {
      widget.onUnlock?.call();
      return;
    }
    setState(() {
      _selectedQuestionId = question.id;
      _answer = widget.engine.answer(question.id, widget.records);
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.engine.questions();

    return Container(
      key: const Key('ask_the_archive_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AskTheArchiveCard.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.locked
                ? AskTheArchiveCard.lockedSubtitle
                : AskTheArchiveCard.subtitle,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final question in questions) ...[
            _QuestionButton(
              prompt: question.prompt,
              selected: _selectedQuestionId == question.id,
              locked: widget.locked,
              onPressed: () => _ask(question),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (!widget.locked && _answer != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              key: const Key('ask_the_archive_answer'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                _answer!.text,
                style: ArchiveMobileTypography.body(context).copyWith(
                  color: AppColors.textPrimary,
                  fontStyle: _answer!.hasEvidence
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionButton extends StatelessWidget {
  const _QuestionButton({
    required this.prompt,
    required this.selected,
    required this.onPressed,
    this.locked = false,
  });

  final String prompt;
  final bool selected;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: selected ? AppColors.accentLight : null,
        side: BorderSide(
          color: selected ? AppColors.accentPrimary : AppColors.borderSubtle,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 12,
        ),
      ),
      child: Row(
        children: [
          if (locked) ...[
            const Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              prompt,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: locked ? AppColors.textSecondary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
