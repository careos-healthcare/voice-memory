import 'package:flutter/material.dart';

import '../features/archive_question/archive_question_engine.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_cards.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import 'archive_why_button.dart';

/// Question The Archive — expandable structured answers (no chat).
class QuestionTheArchiveMobile extends StatefulWidget {
  const QuestionTheArchiveMobile({
    super.key,
    required this.entries,
    required this.state,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3 state;

  @override
  State<QuestionTheArchiveMobile> createState() => _QuestionTheArchiveMobileState();
}

class _QuestionTheArchiveMobileState extends State<QuestionTheArchiveMobile> {
  ArchiveQuestionId? _expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          ArchiveQuestionEngine.headline,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap a question — the archive explains itself from your reflections.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ArchiveQuestionId.values.map((id) {
            final selected = _expanded == id;
            return ChoiceChip(
              label: Text(ArchiveQuestionEngine.buttonLabels[id]!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _expanded = selected ? null : id;
                });
              },
            );
          }).toList(),
        ),
        if (_expanded != null) ...[
          const SizedBox(height: 12),
          _AnswerCard(
            questionId: _expanded!,
            answer: ArchiveQuestionEngine.answer(
              _expanded!,
              entries: widget.entries,
              state: widget.state,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.questionId,
    this.answer,
  });

  final ArchiveQuestionId questionId;
  final ArchiveQuestionAnswer? answer;

  @override
  Widget build(BuildContext context) {
    if (answer == null) {
      return const Text(
        'Not enough archive data yet.',
        style: TextStyle(color: AppTheme.muted),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question',
                      style: TextStyle(fontSize: 10, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      answer!.questionLabel,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ArchiveWhyButton(
                ref: insightRefForArchiveQuestion(questionId),
                askPrompt: ArchiveQuestionEngine.buttonLabels[questionId],
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Archive answer',
            style: TextStyle(fontSize: 10, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          ...answer!.answerLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(color: AppTheme.muted, height: 1.45),
              ),
            ),
          ),
          if (answer!.evidenceLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Evidence',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
            const SizedBox(height: 6),
            ...answer!.evidenceLines.map(
              (line) => Text(
                line,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
