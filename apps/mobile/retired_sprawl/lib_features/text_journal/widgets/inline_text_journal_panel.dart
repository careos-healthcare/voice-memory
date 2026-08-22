import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/image_evidence/image_evidence_attachment_panel.dart';
import 'package:archiveme_mobile/features/text_journal/text_journal_capture_coordinator.dart';
import 'package:archiveme_mobile/features/text_journal/text_journal_copy.dart';
import 'package:archiveme_mobile/features/text_journal/text_journal_state.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Inline text journaling panel — no microphone permission required.
class InlineTextJournalPanel extends StatefulWidget {
  const InlineTextJournalPanel({
    required this.coordinator, required this.onSaved, super.key,
    this.promptHint,
    this.showImageAttachment = true,
  });

  final TextJournalCaptureCoordinator coordinator;
  final Future<void> Function() onSaved;
  final String? promptHint;
  final bool showImageAttachment;

  @override
  State<InlineTextJournalPanel> createState() => _InlineTextJournalPanelState();
}

class _InlineTextJournalPanelState extends State<InlineTextJournalPanel> {
  final _controller = TextEditingController();
  ImageEvidence? _imageEvidence;

  @override
  void initState() {
    super.initState();
    widget.coordinator.begin(promptHint: widget.promptHint);
    _controller.addListener(() {
      widget.coordinator.updateText(_controller.text);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await widget.coordinator.save(imageEvidence: _imageEvidence);
    if (!mounted || result == null) {
      setState(() {});
      return;
    }
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.coordinator.draft;
    final saving = draft.phase == TextJournalPhase.saving;

    return Container(
      key: const Key('inline_text_journal_panel'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TextJournalCopy.panelTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            TextJournalCopy.panelLead,
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('inline_text_journal_field'),
            controller: _controller,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: draft.promptHint ?? TextJournalCopy.placeholder,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.showImageAttachment) ...[
            const SizedBox(height: 12),
            ImageEvidenceAttachmentPanel(
              initial: _imageEvidence,
              enabled: !saving,
              onChanged: (value) => setState(() => _imageEvidence = value),
            ),
          ],
          if (draft.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              draft.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('inline_text_journal_save'),
              onPressed: draft.canSave && !saving
                  ? _save
                  : null,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(TextJournalCopy.saveCta),
            ),
          ),
        ],
      ),
    );
  }
}