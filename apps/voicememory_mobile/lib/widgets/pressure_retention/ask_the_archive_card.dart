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
  });

  final List<PressureCheckInRecord> records;
  final ArchiveReflectionEngine engine;

  static const title = 'Ask the archive';
  static const subtitle =
      'Evidence-based answers from your own saved moments.';

  @override
  State<AskTheArchiveCard> createState() => _AskTheArchiveCardState();
}

class _AskTheArchiveCardState extends State<AskTheArchiveCard> {
  String? _selectedQuestionId;
  ArchiveReflectionAnswer? _answer;

  void _ask(ArchiveReflectionQuestion question) {
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
            AskTheArchiveCard.subtitle,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final question in questions) ...[
            _QuestionButton(
              prompt: question.prompt,
              selected: _selectedQuestionId == question.id,
              onPressed: () => _ask(question),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (_answer != null) ...[
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
                  fontStyle:
                      _answer!.hasEvidence ? FontStyle.normal : FontStyle.italic,
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
  });

  final String prompt;
  final bool selected;
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
      child: Text(
        prompt,
        style: ArchiveMobileTypography.body(context).copyWith(
          color: AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
