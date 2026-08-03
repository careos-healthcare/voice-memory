import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_error_message.dart';
import '../features/archive_export/archive_ownership_copy.dart';
import '../features/archive_export/complete_archive_export.dart';
import '../features/archive_export/full_archive_export.dart';
import '../features/archive_export/readable_archive_temp_files.dart';
import '../features/changes/change_thread_projection.dart';
import '../features/changes/change_thread_repository.dart';
import '../features/weekly_review/weekly_review.dart';
import '../features/weekly_review/weekly_review_repository.dart';
import '../security/private_data_service.dart';
import '../services/analytics/operational_analytics.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

typedef ArchiveExportHandoff =
    Future<void> Function(List<File> files, String subject);

/// Injectable platform edges for deterministic tests. Production keeps the
/// real app-private temporary directory, package version, and OS share sheet.
final class ExportScreenDependencies {
  const ExportScreenDependencies({
    required this.temporaryDirectory,
    required this.appVersion,
    required this.handoff,
  });

  factory ExportScreenDependencies.production() => ExportScreenDependencies(
    temporaryDirectory: getTemporaryDirectory,
    appVersion: () async {
      final package = await PackageInfo.fromPlatform();
      return '${package.version}+${package.buildNumber}';
    },
    handoff: (files, subject) => Share.shareXFiles(
      files.map((file) => XFile(file.path)).toList(growable: false),
      subject: subject,
    ),
  );

  final Future<Directory> Function() temporaryDirectory;
  final Future<String> Function() appVersion;
  final ArchiveExportHandoff handoff;
}

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, this.dependencies});

  final ExportScreenDependencies? dependencies;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late final ExportScreenDependencies _dependencies =
      widget.dependencies ?? ExportScreenDependencies.production();

  static const String description =
      'Choose a readable export for your text and history, or a full archive '
      'that also copies every available original recording into one ZIP.';

  static const String audioNote =
      'Readable archive: audio bytes are excluded. Full archive: available '
      'recordings are decrypted only while the ZIP is built. After sharing, '
      'the destination you choose controls the plaintext files.';
  bool _busy = false;
  String? _message;
  ArchiveExportCancellation? _cancellation;

  /// The Changes projection is part of the export, but a projection failure
  /// must never be a reason the user cannot take their own moments with them.
  Future<ChangeThreadProjection> _changesOrEmpty() async {
    try {
      return await ChangeThreadRepository.refresh();
    } on Object {
      return const ChangeThreadProjection.empty();
    }
  }

  Future<List<WeeklyReview>> _weeklyReviews() async {
    try {
      final state = await WeeklyReviewRepository.storeOrNull()?.read();
      return state?.history ?? const [];
    } on Object {
      return const [];
    }
  }

  Future<void> _exportReadable() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    ReadableArchiveTempFiles? tempFiles;
    try {
      await ExportOperationalAnalytics.started(
        OperationalExportFormat.readable,
      );
      final bundle =
          await PrivateDataService(
            journalStore: AppServices.instance.journalStore,
          ).buildCompleteExport(
            changes: await _changesOrEmpty(),
            weeklyReviews: await _weeklyReviews(),
          );

      final dir = await _dependencies.temporaryDirectory();
      tempFiles = await ReadableArchiveTempFiles.create(dir);
      await tempFiles.write(bundle);

      await _dependencies.handoff([
        tempFiles.readable,
        tempFiles.machineReadable,
      ], 'ArchiveMe readable archive');

      final manifest = bundle.manifest;
      await ExportOperationalAnalytics.completed(
        OperationalExportFormat.readable,
        manifest.entryCount,
      );
      setState(
        () => _message =
            'Readable archive ready: ${manifest.entryCount} saved moments '
            '(${manifest.deletedEntryCount} deleted), '
            '${manifest.correctionCount} corrections, '
            '${manifest.changeThreadCount} threads, and '
            '${manifest.weeklyReviewCount} weekly reviews. Audio bytes were '
            'excluded.',
      );
    } catch (e) {
      await ExportOperationalAnalytics.failed(
        OperationalExportFormat.readable,
        OperationalFailureCategory.unknown,
      );
      setState(
        () => _message = userFacingErrorMessage(
          e,
          fallback: 'Export failed. Try again.',
        ),
      );
    } finally {
      await tempFiles?.cleanup();
      setState(() => _busy = false);
    }
  }

  Future<void> _exportFull() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Include original recordings?'),
            content: const Text(
              'The full archive is one plaintext ZIP containing your readable '
              'archive, JSON, and every available original recording. Anyone '
              'with the ZIP can read or play it. The destination you choose '
              'controls it after sharing.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                key: const Key('confirm_full_audio_export'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Include audio and continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final cancellation = ArchiveExportCancellation();
    setState(() {
      _busy = true;
      _message = null;
      _cancellation = cancellation;
    });
    FullArchiveExportResult? result;
    try {
      await ExportOperationalAnalytics.started(OperationalExportFormat.full);
      result =
          await PrivateDataService(
            journalStore: AppServices.instance.journalStore,
            audioVault: AppServices.instance.journalAudioVault,
            tempDirProvider: _dependencies.temporaryDirectory,
          ).buildFullExport(
            changes: await _changesOrEmpty(),
            weeklyReviews: await _weeklyReviews(),
            appVersion: await _dependencies.appVersion(),
            audioExportConfirmed: true,
            cancellation: cancellation,
          );
      await _dependencies.handoff([result.archive], 'ArchiveMe full archive');
      final reports = result.manifest['reports'] as Map<String, Object?>;
      final unavailable = reports.values.fold<int>(
        0,
        (total, value) => total + (value as List).length,
      );
      await ExportOperationalAnalytics.completed(
        OperationalExportFormat.full,
        (result.manifest['items'] as List).length,
      );
      if (mounted) {
        setState(
          () => _message =
              'Full archive ready as one ZIP. '
              '$unavailable recording${unavailable == 1 ? '' : 's'} could not '
              'be included; details are in manifest.json.',
        );
      }
    } on ArchiveExportCancelled {
      await ExportOperationalAnalytics.failed(
        OperationalExportFormat.full,
        OperationalFailureCategory.cancelled,
      );
      if (mounted) setState(() => _message = 'Export cancelled.');
    } catch (e) {
      await ExportOperationalAnalytics.failed(
        OperationalExportFormat.full,
        OperationalFailureCategory.unknown,
      );
      if (mounted) {
        setState(
          () => _message = userFacingErrorMessage(
            e,
            fallback: 'Export failed. Try again.',
          ),
        );
      }
    } finally {
      await result?.cleanup();
      if (mounted) {
        setState(() {
          _busy = false;
          _cancellation = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Export',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final promise in ArchiveOwnershipCopy.all)
              Padding(
                key: Key('export_promise_$promise'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(promise, style: const TextStyle(height: 1.4)),
              ),
            const SizedBox(height: 12),
            const Text(
              description,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              audioNote,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              ArchiveExportManifest.accessNote,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your encrypted sync recovery code is never included in an '
              'archive export. Keep it separately if recovery is enabled.',
              key: Key('export_recovery_code_reminder'),
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('export_readable_archive'),
              onPressed: _busy ? null : _exportReadable,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Readable archive (no audio bytes)'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('export_full_archive'),
              onPressed: _busy ? null : _exportFull,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Full archive (includes available audio)'),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('cancel_archive_export'),
                onPressed: _cancellation == null
                    ? null
                    : () => _cancellation!.cancel(),
                icon: const Icon(Icons.close),
                label: Text(
                  _cancellation == null ? 'Exporting…' : 'Cancel full export',
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
