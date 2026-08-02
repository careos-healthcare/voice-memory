import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../features/insight_feedback/insight_feedback_store.dart';
import '../features/monetization/data/monetization_local_migration.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../features/processing_preferences/processing_preferences_store.dart';
import '../features/recording/domain/application/interpretation_disposition_coordinator.dart';
import '../features/recording/domain/application/post_save_experience_coordinator.dart';
import '../features/recording/domain/application/save_moment_coordinator.dart';
import '../features/recording/post_capture_choice_sheet.dart';
import '../features/remote_transcription/remote_transcription_disclosure.dart';
import '../features/remote_transcription/remote_transcription_disclosure_dialog.dart';
import '../models/journal_entry.dart';
import '../security/private_data_service.dart';
import '../services/app_services.dart';
import '../services/privacy/encrypted_audio_playback_controller.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../widgets/record/focused_auditable_post_save_section.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  JournalEntry? _entry;
  PostSaveExperience? _postSaveExperience;
  bool _loaded = false;
  bool _analysisInFlight = false;
  String? _analysisStatus;
  String? _error;
  late final EncryptedAudioPlaybackController _playback;
  late final InterpretationDispositionCoordinator _interpretation;

  @override
  void initState() {
    super.initState();
    _playback = EncryptedAudioPlaybackController(
      vault: AppServices.instance.journalAudioVault,
    )..addListener(_onPlaybackChanged);
    final services = AppServices.instance;
    _interpretation = InterpretationDispositionCoordinator(
      journal: () => AppServices.instance.journalStore,
      runner: RemoteInterpretationAnalysisRunner(
        api: services.voiceCaptureApi,
        attest: services.attest,
      ),
      disclosure: services.remoteTranscriptionDisclosure,
      preferences: ProcessingPreferencesStore(
        prefs: () => AppServices.instance.prefs,
        archiveId: () => AppServices.instance.journalStore.ownerArchiveId,
      ),
    );
    unawaited(_load());
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final entryId = widget.entryId;
    final services = AppServices.instance;
    final archiveId = services.journalStore.ownerArchiveId;
    final entry = await services.journalStore.getById(entryId);
    if (!_stillViewing(entryId, archiveId)) return;
    PostSaveExperience? experience;
    if (entry?.reflection.explainableConclusion != null &&
        entry!.ownerArchiveId == archiveId &&
        !entry.isDeleted &&
        !entry.isArchived) {
      final entries = await services.journalStore.loadAll();
      if (!_stillViewing(entryId, archiveId)) return;
      await InsightFeedbackStore.ensureLoaded();
      if (!_stillViewing(entryId, archiveId)) return;
      experience = const PostSaveExperienceCoordinator().build(
        SavedMomentResult(
          entry: entry,
          entries: entries,
          analysisSucceeded: true,
          syncSucceeded: false,
        ),
        feedback: InsightFeedbackStore.cached,
      );
    }
    if (!_stillViewing(entryId, archiveId)) return;
    setState(() {
      _entry = entry;
      _postSaveExperience = experience?.hasConclusion == true
          ? experience
          : null;
      _loaded = true;
    });
  }

  bool _stillViewing(String entryId, String archiveId) =>
      mounted &&
      widget.entryId == entryId &&
      AppServices.instance.journalStore.ownerArchiveId == archiveId;

  bool _canRequestInterpretation(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    return entry.ownerArchiveId ==
            AppServices.instance.journalStore.ownerArchiveId &&
        !entry.isDeleted &&
        !entry.isArchived &&
        transcript.isNotEmpty &&
        !transcript.startsWith('[draft]') &&
        entry.reflection.explainableConclusion == null;
  }

  Future<InterpretationDisposition?> _requestInterpretationChoice(
    String entryId,
    String archiveId,
  ) async {
    if (!_stillViewing(entryId, archiveId)) return null;
    final choice = await showInterpretationChoiceSheet(context: context);
    if (!_stillViewing(entryId, archiveId)) return null;
    return choice;
  }

  Future<bool> _requestInterpretationDisclosure(
    String entryId,
    String archiveId,
  ) async {
    if (!_stillViewing(entryId, archiveId)) return false;
    final action = await showRemoteTranscriptionDisclosure(
      context: context,
      store: AppServices.instance.remoteTranscriptionDisclosure,
      purpose: RemoteProcessingPurpose.interpretation,
    );
    if (!_stillViewing(entryId, archiveId)) return false;
    return action == RemoteTranscriptionDisclosureAction.continueOnline;
  }

  Future<void> _requestLaterInterpretation() async {
    final entry = _entry;
    if (_analysisInFlight ||
        entry == null ||
        !_canRequestInterpretation(entry)) {
      return;
    }
    final entryId = entry.id;
    final archiveId = AppServices.instance.journalStore.ownerArchiveId;
    setState(() {
      _analysisInFlight = true;
      _analysisStatus = 'Preparing a possible read…';
      _error = null;
    });
    try {
      final services = AppServices.instance;
      final subscription =
          services.subscriptionRepository.currentState ??
          await services.subscriptionRepository.loadCachedState() ??
          SubscriptionState.free();
      if (!_stillViewing(entryId, archiveId)) return;

      var productValue = const ProductValueState();
      var legacyGrandfathered = false;
      try {
        final migration = await MonetizationLocalMigration(
          services.prefs,
        ).run(subscription: subscription);
        if (!_stillViewing(entryId, archiveId)) return;
        productValue = migration.productValue;
        legacyGrandfathered = migration.legacyGrandfathered;
      } on Object {
        if (!_stillViewing(entryId, archiveId)) return;
        // Local commercial bookkeeping must not hide a server-authorized
        // request for a user-owned saved moment.
      }

      final outcome = await _interpretation.requestForExistingEntry(
        entryId: entryId,
        requestChoice: () => _requestInterpretationChoice(entryId, archiveId),
        requestDisclosure: () =>
            _requestInterpretationDisclosure(entryId, archiveId),
        entitlement: EntitlementSnapshot.fromSubscriptionState(
          subscription,
          legacyGrandfathered: legacyGrandfathered,
        ),
        // The analyze endpoint is authoritative for the current allowance.
        usage: const UsageSnapshot.serverAuthoritative(),
        productValue: productValue,
      );
      if (!_stillViewing(entryId, archiveId)) return;

      final latest = await services.journalStore.getById(entryId);
      if (!_stillViewing(entryId, archiveId) ||
          latest == null ||
          latest.ownerArchiveId != archiveId ||
          latest.isDeleted ||
          latest.isArchived) {
        return;
      }
      if (outcome.kind == InterpretationOutcomeKind.generated ||
          outcome.kind == InterpretationOutcomeKind.alreadyPresent) {
        await _load();
        if (!_stillViewing(entryId, archiveId)) return;
      }
      setState(() => _analysisStatus = outcome.note);
    } on Object {
      if (!_stillViewing(entryId, archiveId)) return;
      setState(() {
        _analysisStatus =
            'A possible read could not be produced. The moment is saved exactly as it is.';
      });
    } finally {
      if (_stillViewing(entryId, archiveId)) {
        setState(() => _analysisInFlight = false);
      }
    }
  }

  Future<void> _editTranscript(JournalEntry entry) async {
    await context.push('/quick-capture', extra: {'entryId': entry.id});
    if (!mounted || widget.entryId != entry.id) return;
    await _load();
  }

  Future<void> _togglePlayback() async {
    final reference = _entry?.localAudioVaultRef;
    if (reference == null || reference.isEmpty) return;
    try {
      if (_playback.isPlaying) {
        await _playback.pause();
      } else if (_playback.position > Duration.zero) {
        await _playback.play(reference, initialPosition: _playback.position);
      } else {
        await _playback.play(reference);
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'The recording could not be played.');
      }
    }
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this saved moment?'),
        content: const Text(
          'This removes the entry, transcript and its encrypted recording from this device and schedules its sync tombstone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('entry_detail_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _playback.stop();
    await PrivateDataService(
      journalStore: AppServices.instance.journalStore,
      audioVault: AppServices.instance.journalAudioVault,
    ).deleteEntrySecurely(entry.id);
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/archive-belief');
  }

  @override
  void dispose() {
    _playback
      ..removeListener(_onPlaybackChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/archive-belief'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Saved moment'),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : entry == null
            ? const Center(child: Text('This saved moment is unavailable.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd().add_jm().format(
                      entry.createdAt.toLocal(),
                    ),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.durationSeconds > 0 ? 'Voice moment' : 'Typed moment',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    container: true,
                    label: 'Your saved words',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          entry.transcript.trim().isEmpty
                              ? 'Transcript processing…'
                              : entry.transcript,
                          key: const Key('entry_detail_recorded_body'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _editTranscript(entry);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit transcript'),
                  ),
                  if (entry.localAudioVaultRef?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _PlaybackCard(
                      controller: _playback,
                      onToggle: _togglePlayback,
                    ),
                  ],
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                  if (_postSaveExperience case final experience?) ...[
                    const SizedBox(height: 24),
                    FocusedAuditablePostSaveSection(
                      experience: experience,
                      analyticsOrigin: 'entry_detail',
                      onEditTranscript: () => unawaited(_editTranscript(entry)),
                      onOpenSavedMoment: () => unawaited(_load()),
                      onRecordNext: (_) => context.go('/record'),
                    ),
                  ] else if (_canRequestInterpretation(entry)) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('entry_detail_generate_read'),
                      onPressed: _analysisInFlight
                          ? null
                          : _requestLaterInterpretation,
                      icon: _analysisInFlight
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Generate a possible read'),
                    ),
                  ],
                  if (_analysisStatus case final status?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        key: const Key('entry_detail_analysis_status'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const Key('entry_detail_delete_button'),
                    onPressed: () => _confirmDelete(entry),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete saved moment'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({required this.controller, required this.onToggle});

  final EncryptedAudioPlaybackController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final duration = controller.duration ?? Duration.zero;
    final maximum = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final position = controller.position.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();
    return Semantics(
      container: true,
      label: 'Encrypted recording playback',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                tooltip: controller.isPlaying
                    ? 'Pause recording'
                    : 'Play recording',
                onPressed: onToggle,
                icon: Icon(
                  controller.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
              Expanded(
                child: Slider(
                  value: position,
                  max: maximum,
                  semanticFormatterCallback: (value) =>
                      '${Duration(milliseconds: value.round()).inSeconds} seconds',
                  onChanged: duration == Duration.zero
                      ? null
                      : (value) => unawaited(
                          controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                        ),
                ),
              ),
              Text(_clock(controller.position)),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
