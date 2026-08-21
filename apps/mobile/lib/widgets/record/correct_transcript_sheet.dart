import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_analytics.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_controller.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Opens the transcript correction sheet for a saved entry.
abstract final class TranscriptCorrection {
  TranscriptCorrection._();

  static Future<JournalEntry?> open(
    BuildContext context, {
    required JournalEntry entry,
    required String source,
    int entryCount = 1,
    String? initialText,
  }) {
    return CorrectTranscriptSheet.show(
      context,
      entry: entry,
      source: source,
      entryCount: entryCount,
      initialText: initialText,
    );
  }
}

/// Bottom sheet for correcting an existing saved transcript.
class CorrectTranscriptSheet extends StatefulWidget {
  const CorrectTranscriptSheet({
    required this.entry, required this.source, required this.entryCount, super.key,
    this.initialText,
  });

  final JournalEntry entry;
  final String source;
  final int entryCount;
  final String? initialText;

  static Future<JournalEntry?> show(
    BuildContext context, {
    required JournalEntry entry,
    required String source,
    int entryCount = 1,
    String? initialText,
  }) {
    TranscriptCorrectionAnalytics.opened(
      source: source,
      entryCount: entryCount,
      hasParentEntry: true,
    );
    return showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: CorrectTranscriptSheet(
          entry: entry,
          source: source,
          entryCount: entryCount,
          initialText: initialText,
        ),
      ),
    );
  }

  @override
  State<CorrectTranscriptSheet> createState() => _CorrectTranscriptSheetState();
}

class _CorrectTranscriptSheetState extends State<CorrectTranscriptSheet> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed =
        widget.initialText ?? ComparableEvidenceText.userText(widget.entry);
    _controller = TextEditingController(text: seed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await TranscriptCorrectionController.apply(
        entry: widget.entry,
        correctedText: text,
      );
      TranscriptCorrectionAnalytics.saved(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on TranscriptCorrectionFailure {
      TranscriptCorrectionAnalytics.failed(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );
      if (!mounted) return;
      setState(() {
        _error = TranscriptCorrectionCopy.saveFailed;
        _saving = false;
      });
    } catch (_, stackTrace) {
      TranscriptCorrectionAnalytics.failed(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );
      if (!mounted) return;
      setState(() {
        _error = TranscriptCorrectionCopy.saveFailed;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _controller.text.trim().isNotEmpty;
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('correct_transcript_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TranscriptCorrectionCopy.sheetTitle,
                key: const Key('correct_transcript_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                TranscriptCorrectionCopy.sheetHelper,
                key: const Key('correct_transcript_sheet_helper'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                TranscriptCorrectionCopy.inputLabel,
                key: const Key('correct_transcript_input_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('correct_transcript_input'),
                controller: _controller,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  key: const Key('correct_transcript_error'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('correct_transcript_save'),
                onPressed: canSave ? () => unawaited(_save()) : null,
                child: const Text(TranscriptCorrectionCopy.saveButton),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('correct_transcript_cancel'),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text(TranscriptCorrectionCopy.cancelButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}