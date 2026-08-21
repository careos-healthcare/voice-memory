import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/core/user/user_settings.dart';
import 'package:archiveme_mobile/features/import/external_import_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backlogImportServiceProvider = Provider<BacklogImportService>((ref) {
  return BacklogImportService(ref.watch(httpTransportProvider));
});

final backlogImportNotifierProvider =
    NotifierProvider<BacklogImportNotifier, BacklogImportProgress>(
      BacklogImportNotifier.new,
    );

class BacklogImportNotifier extends Notifier<BacklogImportProgress> {
  @override
  BacklogImportProgress build() => const BacklogImportProgress();

  BacklogImportService get _service => ref.read(backlogImportServiceProvider);

  Future<void> pickAndImport() async {
    if (state.isActive) return;

    state = state.copyWith(
      phase: BacklogImportPhase.picking,
      clearError: true,
      statusMessage: 'Choose your export files…',
    );

    final files = await _service.pickExportFiles();
    if (files.isEmpty) {
      state = const BacklogImportProgress(
        statusMessage: 'No files selected.',
      );
      return;
    }

    await importFromFiles(files);
  }

  Future<void> importFromFiles(List<PlatformFile> files) async {
    if (state.isActive) return;

    state = state.copyWith(
      phase: BacklogImportPhase.parsing,
      clearError: true,
      statusMessage: 'Reading your notes…',
    );

    try {
      final chunks = _service.parseSelectedFiles(files);
      state = state.copyWith(
        totalChunks: chunks.length,
        statusMessage: chunks.isEmpty
            ? 'No entries found in those files.'
            : 'Found ${chunks.length} entries to import.',
      );

      // Mirror historical notes into local journal for cold-start browsing.
      final localCoordinator = ExternalImportCoordinator(
        V1AccountDependencies.fromAppServices().journalStore,
      );
      await localCoordinator.importFiles(files);

      final settings = AppServices.isInitialized
          ? await AppServices.instance.userSettings.load()
          : const UserSettings();
      final activeLens = settings.resolvedLens.isThematic
          ? settings.resolvedLens.wireValue
          : null;

      await _service.uploadQueue(
        chunks,
        onProgress: (progress) => state = progress,
        activeLens: activeLens,
      );
    } catch (error, stackTrace) {
      state = BacklogImportProgress(
        phase: BacklogImportPhase.error,
        totalChunks: state.totalChunks,
        processedChunks: state.processedChunks,
        importedCount: state.importedCount,
        failedCount: state.failedCount,
        errorMessage: error.toString(),
        statusMessage: 'Import failed.',
      );
    }
  }

  void reset() {
    state = const BacklogImportProgress();
  }
}