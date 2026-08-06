import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../core/di/v1_account_dependencies.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../services/capture_pipeline_service.dart';
import '../services/product_analytics.dart';
import '../features/first_use_wording/first_use_wording_analytics.dart';
import '../features/first_use_wording/first_use_wording_model.dart';
import '../features/record_capture_modes/record_capture_mode_copy.dart';
import '../features/record_capture_modes/record_capture_mode_engine.dart';
import '../record/quick_text_capture_copy.dart';
import '../record/start_here_visibility.dart';
import '../theme/voicememory_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/record/focused_type_entry_examples_panel.dart';
import '../widgets/record/first_use_wording_helper_card.dart';
import '../widgets/record/start_here_recording_section.dart';
import '../widgets/moment_quality_card.dart';

class QuickTextCaptureScreen extends StatefulWidget {
  const QuickTextCaptureScreen({
    super.key,
    this.initialText,
    this.entryId,
    this.promptHint,
    this.helperText,
    this.captureModeId,
    this.allowQuietDaySave = false,
    this.showFirstUseWordingHelper = false,
    this.focusedRecordTypeEntry = false,
    this.accountDependencies,
  });

  /// Optional prompt hint from conversation starters — never prefilled as editable text.
  final String? initialText;

  /// When set, typed text is attached to this existing voice entry.
  final String? entryId;

  /// Capture-mode question shown as hint — never saved as transcript.
  final String? promptHint;

  /// Capture-mode helper shown above the field — never saved as transcript.
  final String? helperText;

  final String? captureModeId;

  /// Quiet-day mode may save a short default phrase when the field is empty.
  final bool allowQuietDaySave;

  /// Show opening prompts in typed capture for early users.
  final bool showFirstUseWordingHelper;

  /// Calm Record → Type instead layout: one field, examples behind toggle.
  final bool focusedRecordTypeEntry;

  final V1AccountDependencies? accountDependencies;

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
  String? _guidedStyleHelper;
  int _recordingCount = 0;
  bool _firstArchiveMilestoneCompleted = false;
  bool _journalLoaded = false;
  bool _examplesExpanded = false;
  bool _focusedStarterSelected = false;

  late final CapturePipelineService _pipeline;

  late final V1AccountDependencies _accountDeps =
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  bool get _useFocusedTypeEntry =>
      widget.focusedRecordTypeEntry && !_isVoiceFallback;

  @override
  void initState() {
    super.initState();
    _pipeline = _accountDeps.pipeline;
    final focusedEntry =
        widget.focusedRecordTypeEntry &&
        widget.entryId?.trim().isNotEmpty != true;
    if (!focusedEntry) {
      final modePrompt = widget.promptHint?.trim();
      final legacySeed = widget.initialText?.trim();
      if (modePrompt != null && modePrompt.isNotEmpty) {
        _promptHint = modePrompt;
      } else if (legacySeed != null && legacySeed.isNotEmpty) {
        _promptHint = legacySeed;
      }
    }
    final initialHelper = widget.helperText?.trim();
    if (initialHelper != null && initialHelper.isNotEmpty) {
      _guidedStyleHelper = initialHelper;
    }
    ProductAnalytics.track('quick_text_capture_started');
    _controller.addListener(_onTextChanged);
    _loadJournalState();
  }

  Future<void> _loadJournalState() async {
    final all = await _accountDeps.journal.loadAll();
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

  void _onFirstUseWordingOpening(FirstUseWordingPrompt prompt) {
    FirstUseWordingAnalytics.selected(
      source: 'text_capture',
      promptType: prompt.id,
    );
    setState(() => _promptHint = prompt.opening);
  }

  bool get _showFirstUseWordingCapturePanel =>
      _journalLoaded &&
      !_isVoiceFallback &&
      FirstUseWordingGates.shouldShow(
        loaded: true,
        entryCount: _recordingCount,
        isReady: true,
        isPostSave: false,
      ) &&
      (widget.showFirstUseWordingHelper || widget.captureModeId != null);

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

  bool get _canQuietDaySave =>
      !_saving &&
      widget.allowQuietDaySave &&
      _controller.text.trim().isEmpty &&
      !_isVoiceFallback;

  bool get _showPromptHelper => _promptHint != null && _controller.text.isEmpty;

  String? get _modeHelperText {
    final helper = _guidedStyleHelper?.trim();
    if (helper == null || helper.isEmpty) return null;
    return helper;
  }

  bool get _isVoiceFallback => widget.entryId?.trim().isNotEmpty == true;

  String get _saveButtonLabel {
    if (_useFocusedTypeEntry) return QuickTextCaptureCopy.saveMomentCta;
    return _isVoiceFallback ? 'Save words' : 'Save Thought';
  }

  String get _fieldPlaceholder {
    if (_useFocusedTypeEntry) {
      if (_focusedStarterSelected) {
        final hint = _promptHint?.trim();
        if (hint != null && hint.isNotEmpty && _controller.text.isEmpty) {
          return hint;
        }
      }
      return QuickTextCaptureCopy.focusedPlaceholder;
    }
    if (_showPromptHelper) return _promptHint!;
    return 'Type your thought here…';
  }

  Future<void> _save({String? overrideText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _saving) return;

    debugPrint('thought_save_tapped');

    setState(() {
      _saving = true;
      _error = null;
    });

    CapturePipelineResult? result;
    try {
      if (_isVoiceFallback) {
        final existing = await _accountDeps.journalStore.getById(
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
        _error = e.message.contains('Enter')
            ? e.message
            : VoiceCaptureCopy.saveFailed;
        _saving = false;
      });
      return;
    } catch (_) {
      debugPrint('thought_save_failed');
      if (!mounted) return;
      setState(() {
        _error = VoiceCaptureCopy.saveFailed;
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
                : _useFocusedTypeEntry
                ? ''
                : 'Type a thought',
          ),
        ),
        body: SafeArea(
          child: _useFocusedTypeEntry
              ? _buildFocusedTypeEntryBody(context)
              : _buildLegacyTypeEntryBody(context, length),
        ),
      ),
    );
  }

  Widget _buildFocusedTypeEntryBody(BuildContext context) {
    const horizontalPadding = 24.0;
    const topPadding = 24.0;
    const bottomPadding = 24.0;
    const maxCardWidth = 520.0;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          bottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxCardWidth),
          child: Container(
            key: const Key('focused_type_entry_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: VoiceMemoryCards.standard(
              background: const Color(0xFFF6F4FF),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('quick_text_capture_field'),
                  controller: _controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _fieldPlaceholder,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('quick_text_capture_save_button'),
                    onPressed: _canSave ? () => unawaited(_save()) : null,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_saveButtonLabel),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    key: const Key('focused_type_entry_use_voice_link'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: VoiceMemoryColors.textSecondary,
                    ),
                    onPressed: _saving
                        ? null
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: Text(
                      QuickTextCaptureCopy.useVoiceInsteadLink,
                      style: const TextStyle(
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FocusedTypeEntryExamplesPanel(
                  expanded: _examplesExpanded,
                  onToggle: () =>
                      setState(() => _examplesExpanded = !_examplesExpanded),
                  onStarterSelected: (opening) {
                    setState(() {
                      _focusedStarterSelected = true;
                      _promptHint = opening;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegacyTypeEntryBody(BuildContext context, int length) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 24.0;
        const topPadding = 16.0;
        const bottomPadding = 24.0;
        // Body already shrinks above the keyboard (resizeToAvoidBottomInset).
        // Do not subtract viewInsets.bottom again — that double-counts and
        // produces negative minHeight on small Android layouts.
        final minScrollBodyHeight =
            (constraints.maxHeight - topPadding - bottomPadding).clamp(
              0.0,
              double.infinity,
            );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minScrollBodyHeight),
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
                if (_modeHelperText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _modeHelperText!,
                    key: const Key('quick_text_capture_mode_helper'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: VoiceMemoryColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (_showFirstUseWordingCapturePanel) ...[
                  const SizedBox(height: 12),
                  FirstUseWordingCapturePanel(
                    compact: widget.captureModeId != null,
                    onUseOpening: _onFirstUseWordingOpening,
                  ),
                ],
                if (_journalLoaded && widget.captureModeId == null) ...[
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
                if (_showPromptHelper && _modeHelperText == null) ...[
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
                    hintText: _fieldPlaceholder,
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
                    onPressed: _canSave ? () => unawaited(_save()) : null,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_saveButtonLabel),
                  ),
                ),
                if (_canQuietDaySave) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      key: const Key('quick_text_capture_quiet_day_save'),
                      onPressed: () => unawaited(
                        _save(
                          overrideText:
                              RecordCaptureModeEngine.quietDaySaveText(),
                        ),
                      ),
                      child: const Text(
                        RecordCaptureModeCopy.quietDaySaveButton,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
