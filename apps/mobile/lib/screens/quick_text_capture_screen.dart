import 'dart:async';

import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_analytics.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_model.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_materializer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_sqlite_writer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/controllers/entry_controller.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/rich_import_copy.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/empty_state_view.dart';
import 'package:archiveme_mobile/features/playback/local_ai_coach.dart';
import 'package:archiveme_mobile/features/playback/local_ai_coaching_parameters_store.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/voice/data/record_dictation_engine.dart';
import 'package:archiveme_mobile/features/voice/presentation/dictation_mic_bar.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/record/quick_text_capture_copy.dart';
import 'package:archiveme_mobile/record/start_here_visibility.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/moment_quality_card.dart';
import 'package:archiveme_mobile/widgets/record/first_use_wording_helper_card.dart';
import 'package:archiveme_mobile/widgets/record/focused_type_entry_examples_panel.dart';
import 'package:archiveme_mobile/widgets/record/local_ai_coaching_parameter_toggles.dart';
import 'package:archiveme_mobile/widgets/record/start_here_recording_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.editorTranscript,
    this.templateWriter,
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

  /// Page body already saved from a template. Fills the field and hides the gallery.
  final String? editorTranscript;

  /// Overrides the SQLite writer. Production uses the open journal database.
  final ArchiveTemplateSqliteWriter? templateWriter;

  @override
  State<QuickTextCaptureScreen> createState() => _QuickTextCaptureScreenState();
}

class _QuickTextCaptureScreenState extends State<QuickTextCaptureScreen> {
  final _controller = TextEditingController();
  final _dictation = RecordDictationEngine();
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
  LocalAiCoachingParameters _coachingParameters =
      const LocalAiCoachingParameters();

  late final CapturePipelineService _pipeline;
  EntryController? _richImportController;

  late final V1AccountDependencies _accountDeps =
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  bool get _useFocusedTypeEntry =>
      widget.focusedRecordTypeEntry && !_isVoiceFallback;

  @override
  void initState() {
    super.initState();
    _pipeline = _accountDeps.pipeline;
    final editorSeed = widget.editorTranscript?.trim();
    if (editorSeed != null && editorSeed.isNotEmpty) {
      _controller.text = editorSeed;
    }
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
    unawaited(ProductAnalytics.track('quick_text_capture_started'));
    _controller.addListener(_onTextChanged);
    unawaited(_loadJournalState());
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
    final coaching = await LocalAiCoachingParametersStore(
      _accountDeps.prefs,
    ).load();
    if (!mounted) return;
    setState(() => _coachingParameters = coaching);
  }

  Future<void> _updateCoachingParameters(
    LocalAiCoachingParameters next,
  ) async {
    setState(() => _coachingParameters = next);
    await LocalAiCoachingParametersStore(_accountDeps.prefs).save(next);
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

  Widget _coachingToggles() {
    return LocalAiCoachingParameterToggles(
      successfulEntryCount: _recordingCount,
      parameters: _coachingParameters,
      onChanged: (next) => unawaited(_updateCoachingParameters(next)),
    );
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _logAbandonedIfNeeded() {
    if (_abandonLogged || _saved) return;
    if (_controller.text.trim().isEmpty) return;
    _abandonLogged = true;
    unawaited(ProductAnalytics.track('quick_text_capture_abandoned'));
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

  bool get _showGuidedEmptyState =>
      !_isVoiceFallback && _controller.text.trim().isEmpty;

  EntryController get _importsController =>
      _richImportController ??= EntryController(
        writer: (entry) => _accountDeps.journalStore.save(
          entry,
          first25Source: 'rich_media_import',
        ),
      );

  void _onRichDraftCreated(JournalEntry _) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(RichImportCopy.draftSaved)),
    );
  }

  ArchiveTemplateSqliteWriter get _templateWriter =>
      widget.templateWriter ??
      ArchiveTemplateSqliteWriter(
        JournalSqliteRepository(AppServices.instance.sqliteDatabase),
      );

  Future<ArchiveTemplateDraft> _persistTemplate(
    ArchiveEntryTemplate template,
  ) {
    return _templateWriter.apply(template);
  }

  Future<void> _openTemplateInEditor(ArchiveEntryTemplate template) async {
    try {
      final draft = await _persistTemplate(template);
      if (!mounted) return;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/editor'),
            builder: (_) => QuickTextCaptureScreen(
              editorTranscript: draft.page.transcript,
              accountDependencies: _accountDeps,
              templateWriter: widget.templateWriter,
            ),
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'archive_template_open_failed',
        name: 'QuickTextCaptureScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this template.')),
      );
    }
  }

  void _onTemplateEvidence(ArchiveTemplateDraft draft) {
    unawaited(_showTemplateEvidence(draft));
  }

  Future<void> _showTemplateEvidence(ArchiveTemplateDraft draft) async {
    try {
      await _persistTemplate(draft.template);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'archive_template_evidence_save_failed',
        name: 'QuickTextCaptureScreen',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    await openEvidenceTrailForSourceEntryIds(
      context,
      sourceEntryIds: draft.evidenceEntryIds,
      surface: 'archive_template_card',
      entries: draft.entries,
    );
  }

  Widget _guidedEmptyState({bool compact = false}) {
    if (!_showGuidedEmptyState) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: EmptyStateView(
        controller: _importsController,
        onDraftCreated: _onRichDraftCreated,
        onOpenTemplate: _openTemplateInEditor,
        onViewTemplateEvidence: _onTemplateEvidence,
        compact: compact,
      ),
    );
  }

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

    AppLogger.debug('thought_save_tapped');

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
        final attachOutcome = await _pipeline.attachTypedTextToVoiceEntry(
          entry: existing,
          transcript: text,
        );
        result = attachOutcome.getOrThrow();
      } else {
        result = (await _pipeline.saveTextThought(transcript: text)).getOrThrow();
      }
      _saved = true;
      AppLogger.debug('thought_save_succeeded');
    } on CapturePipelineFailure catch (e, stackTrace) {
      AppLogger.debug('thought_save_failed');
      if (!mounted) return;
      setState(() {
        _error = e.message.contains('Enter')
            ? e.message
            : VoiceCaptureCopy.saveFailed;
        _saving = false;
      });
      return;
    } catch (_, stackTrace) {
      AppLogger.debug('thought_save_failed');
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
        key: widget.editorTranscript?.trim().isNotEmpty == true
            ? const Key('archive_template_editor')
            : null,
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
                _guidedEmptyState(compact: true),
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
                _dictationBar(),
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
                    child: const Text(
                      QuickTextCaptureCopy.useVoiceInsteadLink,
                      style: TextStyle(
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
                _coachingToggles(),
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
                  const Text(
                    ConsumerUiCopy.trySayingLabel,
                    style: TextStyle(
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
                _guidedEmptyState(),
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
                _dictationBar(),
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
                _coachingToggles(),
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

  Widget _dictationBar() {
    return DictationMicBar(
      controller: _controller,
      engine: _dictation,
      onVoiceCall: () => context.push(RouteCatalog.voiceCall),
    );
  }
}