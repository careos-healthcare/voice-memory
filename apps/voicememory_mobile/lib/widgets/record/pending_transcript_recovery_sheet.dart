import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../features/trust/pending_transcript_recovery_analytics.dart';
import '../../features/trust/pending_transcript_recovery_copy.dart';

/// Opens typed-text recovery for a pending voice moment.
abstract final class PendingTranscriptRecovery {
  PendingTranscriptRecovery._();

  static Future<CapturePipelineResult?> open(
    BuildContext context, {
    required JournalEntry entry,
    required String source,
    int entryCount = 1,
  }) {
    return PendingTranscriptRecoverySheet.show(
      context,
      entry: entry,
      source: source,
      entryCount: entryCount,
    );
  }
}

/// Bottom sheet for attaching typed correction to an existing pending entry.
class PendingTranscriptRecoverySheet extends StatefulWidget {
  const PendingTranscriptRecoverySheet({
    super.key,
    required this.entry,
    required this.source,
    required this.entryCount,
  });

  final JournalEntry entry;
  final String source;
  final int entryCount;

  static Future<CapturePipelineResult?> show(
    BuildContext context, {
    required JournalEntry entry,
    required String source,
    int entryCount = 1,
  }) {
    PendingTranscriptRecoveryAnalytics.opened(
      source: source,
      entryCount: entryCount,
      hasParentEntry: true,
    );
    return showModalBottomSheet<CapturePipelineResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PendingTranscriptRecoverySheet(
          entry: entry,
          source: source,
          entryCount: entryCount,
        ),
      ),
    );
  }

  @override
  State<PendingTranscriptRecoverySheet> createState() =>
      _PendingTranscriptRecoverySheetState();
}

class _PendingTranscriptRecoverySheetState
    extends State<PendingTranscriptRecoverySheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

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
      final existing = await AppServices.instance.journalStore.getById(
        widget.entry.id,
      );
      if (existing == null) {
        throw CapturePipelineFailure(PendingTranscriptRecoveryCopy.saveFailed);
      }

      final result = await AppServices.instance.pipeline.attachTypedTextToVoiceEntry(
        entry: existing,
        transcript: text,
      );

      PendingTranscriptRecoveryAnalytics.saved(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on CapturePipelineFailure {
      PendingTranscriptRecoveryAnalytics.failed(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );
      if (!mounted) return;
      setState(() {
        _error = PendingTranscriptRecoveryCopy.saveFailed;
        _saving = false;
      });
    } catch (_) {
      PendingTranscriptRecoveryAnalytics.failed(
        source: widget.source,
        entryCount: widget.entryCount,
        hasParentEntry: true,
      );
      if (!mounted) return;
      setState(() {
        _error = PendingTranscriptRecoveryCopy.saveFailed;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _controller.text.trim().isNotEmpty;

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
            key: const Key('pending_transcript_recovery_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PendingTranscriptRecoveryCopy.inputTitle,
                key: const Key('pending_transcript_recovery_input_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PendingTranscriptRecoveryCopy.inputHelper,
                key: const Key('pending_transcript_recovery_input_helper'),
                style: ArchiveMobileTypography.explanationBody(context).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('pending_transcript_recovery_input'),
                controller: _controller,
                autofocus: false,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  key: const Key('pending_transcript_recovery_error'),
                  style: ArchiveMobileTypography.explanationBody(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('pending_transcript_recovery_save'),
                onPressed: canSave ? _save : null,
                child: Text(PendingTranscriptRecoveryCopy.saveButton),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('pending_transcript_recovery_cancel'),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(PendingTranscriptRecoveryCopy.cancelButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
