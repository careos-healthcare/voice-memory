import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/processing_preferences/processing_preferences.dart';
import '../router/route_catalog.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';

/// Focused V1 typed capture.
///
/// Context collection, capture modes, beta missions, and experimental cards
/// are intentionally absent from the shipping dependency graph.
class QuickTextCaptureScreen extends StatefulWidget {
  const QuickTextCaptureScreen({
    super.key,
    this.initialText,
    this.entryId,
    this.queueJobId,
    this.promptHint,
    this.helperText,
    this.captureModeId,
    this.allowQuietDaySave = false,
    this.showFirstUseWordingHelper = false,
    this.focusedRecordTypeEntry = false,
    this.returnToRecordAfterSave = false,
    @Deprecated('Ambient location and calendar context are not in V1')
    Object? ambientContextService,
  });

  final String? initialText;
  final String? entryId;
  final String? queueJobId;
  final String? promptHint;
  final String? helperText;
  final String? captureModeId;
  final bool allowQuietDaySave;
  final bool showFirstUseWordingHelper;
  final bool focusedRecordTypeEntry;
  final bool returnToRecordAfterSave;

  @override
  State<QuickTextCaptureScreen> createState() => _QuickTextCaptureScreenState();
}

class _QuickTextCaptureScreenState extends State<QuickTextCaptureScreen> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deliberately empty. A suggested prompt arrives as [initialText] and is
    // offered as hint text only: seeding the field would let app-authored
    // words be saved as the user's own, which is the one thing a moment must
    // never contain. The router forwards a bare String extra straight into
    // this parameter, so the rule is enforced here rather than at call sites.
    _controller = TextEditingController();
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
      final services = AppServices.instance;
      final entryId = widget.entryId?.trim();
      final CapturePipelineResult result;
      if (entryId != null && entryId.isNotEmpty) {
        final entries = await services.journalStore.loadAll();
        final entry = entries.where((item) => item.id == entryId).firstOrNull;
        if (entry == null) {
          throw StateError('The saved recording could not be found.');
        }
        result = await services.pipeline.attachTypedTextToVoiceEntry(
          entry: entry,
          transcript: text,
          currentInterpretationChoice:
              InterpretationPreference.saveWithoutInterpretation,
        );
      } else {
        result = await services.pipeline.saveTextThought(
          transcript: text,
          currentInterpretationChoice:
              InterpretationPreference.saveWithoutInterpretation,
        );
      }
      if (!mounted) return;
      if (widget.returnToRecordAfterSave) {
        context.go(RouteCatalog.recordHome, extra: result);
      } else {
        context.pop(result);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'This moment could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Type a moment')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.promptHint?.trim().isNotEmpty == true
                ? widget.promptHint!
                : 'What happened, in your own words?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.helperText?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(widget.helperText!),
          ],
          const SizedBox(height: 20),
          TextField(
            key: const Key('quick_text_capture_field'),
            controller: _controller,
            autofocus: true,
            minLines: 6,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.initialText?.trim().isNotEmpty == true
                  ? widget.initialText!.trim()
                  : 'Type your moment here…',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              key: const Key('quick_text_capture_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('quick_text_capture_save'),
            onPressed: _saving || _controller.text.trim().isEmpty
                ? null
                : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save moment'),
          ),
        ],
      ),
    ),
  );
}
