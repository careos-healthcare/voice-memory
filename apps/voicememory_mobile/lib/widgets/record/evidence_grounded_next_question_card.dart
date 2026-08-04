import 'package:flutter/material.dart';

import '../../features/adaptive_question/adaptive_question.dart';
import '../../theme/app_spacing.dart';
import 'post_save_action_button.dart';

/// The one question that closes the post-save experience.
///
/// It is a single question the reader can dismiss, never a thread of them, and
/// it carries no primary action of its own so the evidence card keeps the one
/// primary call to action on the surface.
///
/// The question text is private content derived from the reader's own words.
/// Nothing here reports it, or anything derived from it, to analytics.
class EvidenceGroundedNextQuestionCard extends StatefulWidget {
  const EvidenceGroundedNextQuestionCard({
    super.key,
    required this.question,
    this.onRecordNext,
  });

  final AdaptiveQuestion question;

  /// Seeds the next recording with this question. The text stays on device.
  final ValueChanged<String>? onRecordNext;

  @override
  State<EvidenceGroundedNextQuestionCard> createState() =>
      _EvidenceGroundedNextQuestionCardState();
}

class _EvidenceGroundedNextQuestionCardState
    extends State<EvidenceGroundedNextQuestionCard> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant EvidenceGroundedNextQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.text != widget.question.text) _dismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final onRecordNext = widget.onRecordNext;
    return Card(
      key: const Key('post_save_next_question_card'),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                container: true,
                label: 'One question for next time',
                child: ExcludeSemantics(
                  child: Text(
                    'One question for next time',
                    key: const Key('post_save_next_question_header'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.question.text,
                key: const Key('post_save_next_question'),
                softWrap: true,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: [
                  if (onRecordNext != null)
                    PostSaveActionButton(
                      key: const Key('post_save_next_question_record'),
                      label: 'Answer this next',
                      onPressed: () => onRecordNext(widget.question.text),
                    ),
                  PostSaveActionButton(
                    key: const Key('post_save_next_question_dismiss'),
                    label: 'Not this',
                    outlined: false,
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
