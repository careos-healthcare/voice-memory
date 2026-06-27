import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../services/product_analytics.dart';
import '../record/start_here_visibility.dart';
import '../theme/voicememory_colors.dart';
import '../widgets/record/start_here_recording_section.dart';
import '../widgets/moment_quality_card.dart';

class QuickTextCaptureScreen extends StatefulWidget {
  const QuickTextCaptureScreen({
    super.key,
    this.initialText,
    this.entryId,
  });

  /// Optional prompt hint from conversation starters — never prefilled as editable text.
  final String? initialText;

  /// When set, typed text is attached to this existing voice entry.
  final String? entryId;

  @override
  State<QuickTextCaptureScreen> createState() => _QuickTextCaptureScreenState();
}

class _QuickTextCaptureScreenState extends State<QuickTextCaptureScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  bool _abandonLogged = false;
  String? _error;
  String? _promptHint;
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
      _promptHint = seed;
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
    setState(() => _promptHint = prompt);
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

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  bool get _showPromptHelper =>
      _promptHint != null && _controller.text.isEmpty;

  bool get _isVoiceFallback => widget.entryId?.trim().isNotEmpty == true;

  String get _saveButtonLabel =>
      _isVoiceFallback ? 'Save words' : 'Save Thought';

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    debugPrint('thought_save_tapped');

    setState(() {
      _saving = true;
      _error = null;
    });

    CapturePipelineResult? result;
    try {
      if (_isVoiceFallback) {
        final existing = await AppServices.instance.journalStore.getById(
          widget.entryId!,
        );
        if (existing == null) {
          throw CapturePipelineFailure('Could not find that recording.');
        }
        result = await _pipeline.attachTypedTextToVoiceEntry(
          entry: existing,
          transcript: text,
        );
      } else {
        result = await _pipeline.saveTextThought(transcript: text);
      }
      _saved = true;
      debugPrint('thought_save_succeeded');
    } on CapturePipelineFailure catch (e) {
      debugPrint('thought_save_failed');
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
      return;
    } catch (_) {
      debugPrint('thought_save_failed');
      if (!mounted) return;
      setState(() {
        _error = 'Could not save this thought. Try again.';
        _saving = false;
      });
      return;
    }

    await ProductAnalytics.track(
      'quick_text_capture_saved',
      parameters: {'char_count': text.length},
    );
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(result);
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            _isVoiceFallback
                ? VoiceCaptureCopy.typeWhatYouSaid
                : 'Type a thought',
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 24.0;
              const topPadding = 16.0;
              const bottomPadding = 24.0;
              // Body already shrinks above the keyboard (resizeToAvoidBottomInset).
              // Do not subtract viewInsets.bottom again — that double-counts and
              // produces negative minHeight on small Android layouts.
              final minScrollBodyHeight = (constraints.maxHeight -
                      topPadding -
                      bottomPadding)
                  .clamp(0.0, double.infinity);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minScrollBodyHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isVoiceFallback
                            ? 'What did you say?'
                            : "What's on your mind?",
                        style: ArchiveMobileTypography.pageTitle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isVoiceFallback
                            ? 'ArchiveMe could not turn your recording into text. Type the words here so this moment stays usable.'
                            : 'A few sentences is enough — same as speaking a short thought.',
                        style: const TextStyle(
                          color: VoiceMemoryColors.textSecondary,
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                      if (_journalLoaded) ...[
                        const SizedBox(height: 12),
                        StartHereRecordingSection(
                          recordingCount: _recordingCount,
                          firstArchiveMilestoneCompleted:
                              _firstArchiveMilestoneCompleted,
                          onPromptSelected: _onStartHereSelected,
                          surface: 'text_capture',
                          captureMode: 'text',
                          compactPrompts: _isVoiceFallback,
                          maxPrompts: _isVoiceFallback ? 2 : null,
                        ),
                      ],
                      if (_showPromptHelper) ...[
                        const SizedBox(height: 12),
                        Text(
                          ConsumerUiCopy.trySayingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: VoiceMemoryColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _promptHint!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VoiceMemoryColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('quick_text_capture_field'),
                        controller: _controller,
                        autofocus: true,
                        minLines: 4,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _showPromptHelper
                              ? _promptHint
                              : 'Type your thought here…',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      MomentQualityCard(text: _controller.text),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('quick_text_capture_save_button'),
                          onPressed: _canSave ? _save : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_saveButtonLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
