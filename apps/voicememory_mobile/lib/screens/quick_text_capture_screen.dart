import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../services/product_analytics.dart';
import '../record/start_here_visibility.dart';
import '../theme/voicememory_colors.dart';
import '../widgets/record/start_here_recording_section.dart';
class QuickTextCaptureScreen extends StatefulWidget {
  const QuickTextCaptureScreen({super.key, this.initialText});

  /// Prefill from conversation starter chips (voice tab long-press or text path).
  final String? initialText;

  @override
  State<QuickTextCaptureScreen> createState() => _QuickTextCaptureScreenState();
}

class _QuickTextCaptureScreenState extends State<QuickTextCaptureScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  bool _abandonLogged = false;
  String? _error;
  int _recordingCount = 0;
  bool _firstArchiveMilestoneCompleted = false;
  bool _journalLoaded = false;

  late final CapturePipelineService _pipeline;

  @override
  void initState() {
    super.initState();
    _pipeline = AppServices.instance.pipeline;
    final seed = widget.initialText?.trim();
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
    }
    ProductAnalytics.track('quick_text_capture_started');
    _controller.addListener(_onTextChanged);
    _loadJournalState();
  }

  Future<void> _loadJournalState() async {
    final all = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _recordingCount = all.length;
      _firstArchiveMilestoneCompleted =
          StartHereVisibility.hasCompletedFirstArchiveMilestone(all);
      _journalLoaded = true;
    });
  }

  void _onStartHereSelected(String prompt) {
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    setState(() {});
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _logAbandonedIfNeeded() {
    if (_abandonLogged || _saved) return;
    if (_controller.text.trim().isEmpty) return;
    _abandonLogged = true;
    ProductAnalytics.track('quick_text_capture_abandoned');
  }

  @override
  void dispose() {
    _logAbandonedIfNeeded();
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _pipeline.saveTextThought(transcript: text);
      _saved = true;
      await ProductAnalytics.track(
        'quick_text_capture_saved',
        parameters: {'char_count': text.length},
      );
      if (!mounted) return;
      context.pop(true);
    } on CapturePipelineFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save this thought. Try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final length = _controller.text.length;

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _logAbandonedIfNeeded();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Type a thought'),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What's on your mind?",
                style: ArchiveMobileTypography.pageTitle(context),
              ),
              const SizedBox(height: 8),
              const Text(
                'A few sentences is enough — same as speaking a short thought.',
                style: TextStyle(
                  color: VoiceMemoryColors.textSecondary,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              if (_journalLoaded) ...[
                const SizedBox(height: 12),
                StartHereRecordingSection(
                  recordingCount: _recordingCount,
                  firstArchiveMilestoneCompleted: _firstArchiveMilestoneCompleted,
                  onPromptSelected: _onStartHereSelected,
                  surface: 'text_capture',
                  captureMode: 'text',
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type your thought here…',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$length characters',
                style: const TextStyle(
                  fontSize: 12,
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Thought'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
