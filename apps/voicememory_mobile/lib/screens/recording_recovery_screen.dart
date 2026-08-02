import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/processing_preferences/processing_preferences_store.dart';
import '../features/recording/domain/application/on_device_transcription_availability.dart';
import '../features/recording/domain/application/post_capture_disposition_coordinator.dart';
import '../features/recording/domain/application/remote_transcription_coordinator.dart';
import '../features/recording/domain/application/vault_persistence_coordinator.dart';
import '../features/recording/post_capture_choice_sheet.dart';
import '../features/remote_transcription/remote_transcription_disclosure_dialog.dart';
import '../router/route_catalog.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../services/privacy/sensitive_temporary_audio_store.dart';
import '../widgets/pushed_screen_shell.dart';

class RecordingRecoveryScreen extends StatefulWidget {
  const RecordingRecoveryScreen({super.key});

  @override
  State<RecordingRecoveryScreen> createState() =>
      _RecordingRecoveryScreenState();
}

class _RecordingRecoveryScreenState extends State<RecordingRecoveryScreen> {
  static const _ttl = Duration(hours: 24);

  List<TemporaryAudioItem>? _items;
  String? _error;
  String? _busyId;

  SensitiveTemporaryAudioStore get _store =>
      SensitiveTemporaryAudioStore.production;
  String get _ownerId =>
      'archive:${AppServices.instance.journalStore.ownerArchiveId}';

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final items = await _store.list(ownerId: _ownerId, recoverableOnly: true);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Recovery storage is temporarily unavailable.');
    }
  }

  Future<void> _delete(TemporaryAudioItem item) async {
    setState(() => _busyId = item.id);
    try {
      await _store.delete(file: item.file, ownerId: _ownerId);
      await _store.purge();
      await _reload();
    } on Object {
      if (mounted) {
        setState(() => _error = 'The recording could not be deleted.');
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Recovered audio uses the same persist-then-choose flow as a live capture.
  Future<void> _recover(TemporaryAudioItem item) async {
    final services = AppServices.instance;
    final remote = RemoteTranscriptionCoordinator(
      disclosure: services.remoteTranscriptionDisclosure,
      executor: services.transcriptionQueueExecutor,
      schedule: services.transcriptionWorkScheduler.schedule,
    );
    final processingPreferences = ProcessingPreferencesStore(
      prefs: () => services.prefs,
      archiveId: () => services.journalStore.ownerArchiveId,
    );
    final disposition = PostCaptureDispositionCoordinator(
      vault: services.journalAudioVault,
      journal: () => services.journalStore,
      onDeviceEngine: services.onDeviceTranscription,
      disclosure: services.remoteTranscriptionDisclosure,
      remoteQueue: VaultPersistenceCoordinator(services.transcriptionLedger),
      startRemoteQueue: () async => remote.start(),
      onlineOnlyPreference: OnlineOnlyTranscriptionPreferenceStore(
        () => services.prefs,
      ),
      preferences: processingPreferences,
      temporaryAudio: _store,
      temporaryAudioOwnerId: _ownerId,
    );

    setState(() => _busyId = item.id);
    var typeInstead = false;
    try {
      final outcome = await disposition.resolve(
        audio: item.file,
        durationSeconds: (item.bytes / 32000).ceil().clamp(1, 7200),
        createdAt: item.createdAt,
        requestChoice: (options) async => mounted
            ? showPostCaptureChoiceSheet(context: context, options: options)
            : null,
        requestRemoteDisclosure: () async {
          if (!mounted) return false;
          final action = await showRemoteTranscriptionDisclosure(
            context: context,
            store: services.remoteTranscriptionDisclosure,
          );
          typeInstead =
              action == RemoteTranscriptionDisclosureAction.typeInstead;
          return action == RemoteTranscriptionDisclosureAction.continueOnline;
        },
        confirmDelete: () async =>
            mounted &&
            await showPostCaptureDeleteConfirmation(context: context),
      );
      if (!mounted) return;
      if (typeInstead && outcome.entry != null) {
        final typed = await context.push<CapturePipelineResult>(
          RouteCatalog.quickTextCapture,
          extra: {'entryId': outcome.entry!.id, 'focusedRecordTypeEntry': true},
        );
        if (typed != null && mounted) {
          context.go(RouteCatalog.recordHome, extra: typed);
          return;
        }
      } else if (outcome.kind == PostCaptureOutcomeKind.transcribedOnDevice &&
          outcome.entry != null) {
        context.go(
          RouteCatalog.recordHome,
          extra: CapturePipelineResult(
            entry: outcome.entry!,
            localSaved: true,
            syncSucceeded: false,
          ),
        );
        return;
      }
      await _reload();
      if (mounted && outcome.note != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(outcome.note!)));
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error =
              'The recording is still protected and can be retried before it expires.';
        });
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PushedScreenShell(
      title: 'Unsaved recordings',
      body: Semantics(
        container: true,
        label: 'Protected unsaved recordings',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Recordings shown here stay on this device and expire 24 hours after capture.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (items == null)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              const Text('There are no unsaved recordings to recover.')
            else
              for (final item in items) _itemCard(context, item),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, TemporaryAudioItem item) {
    final now = DateTime.now().toUtc();
    final age = now.difference(item.createdAt);
    final remaining = _ttl - age;
    final approximateSeconds = (item.bytes / 32000).round().clamp(1, 7200);
    final busy = _busyId == item.id;
    return Card(
      key: ValueKey('recovery-${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unsaved recording',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'About ${_duration(approximateSeconds)} · captured ${_age(age)} ago',
            ),
            const SizedBox(height: 4),
            Text(
              'Expires in ${_remaining(remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => _recover(item),
                  child: const Text('Recover and encrypt'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _delete(item),
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Keep for now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(int seconds) =>
      seconds < 60 ? '$seconds seconds' : '${(seconds / 60).ceil()} minutes';

  static String _age(Duration age) {
    if (age.inHours > 0) return '${age.inHours} hours';
    return '${age.inMinutes.clamp(1, 59)} minutes';
  }

  static String _remaining(Duration remaining) {
    if (remaining.isNegative) return 'less than a minute';
    if (remaining.inHours > 0) return '${remaining.inHours} hours';
    return '${remaining.inMinutes.clamp(1, 59)} minutes';
  }
}
