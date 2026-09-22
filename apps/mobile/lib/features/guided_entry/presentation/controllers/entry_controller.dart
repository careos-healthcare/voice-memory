import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/core/services/activity_metadata_service.dart';
import 'package:archiveme_mobile/core/services/location_service.dart';
import 'package:archiveme_mobile/core/services/media_picker_service.dart';
import 'package:archiveme_mobile/core/services/rich_import_permission_client.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/rich_import_copy.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/time_of_day_prompt.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_voice_persistence.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Persists a rich-import draft on the device.
typedef DraftEntryWriter = Future<void> Function(JournalEntry entry);

/// Outcome of a one-tap import.
sealed class ImportResult {
  const ImportResult();
}

/// A draft was written locally and does not need typed text first.
class ImportCreated extends ImportResult {
  const ImportCreated(this.entry);

  final JournalEntry entry;
}

/// The import stopped after a permission or lookup failure.
class ImportFailed extends ImportResult {
  const ImportFailed(this.message);

  final String message;
}

/// The person dismissed the soft prompt or the activity picker.
class ImportCancelled extends ImportResult {
  const ImportCancelled();
}

/// Builds a local journal draft from a photo, neighborhood, or activity.
class EntryController {
  EntryController({
    required this._writer,
    MediaPickerService? mediaPicker,
    LocationService? locationService,
    ActivityMetadataService? activityService,
    SystemPermissionClient? permissions,
    String Function()? newId,
  }) : _mediaPicker = mediaPicker ?? MediaPickerService(),
       _locationService = locationService ?? LocationService(),
       _activityService = activityService ?? ActivityMetadataService(),
       _permissions = permissions ?? V1GuardedPermissionClient(),
       _newId = newId ?? _defaultId;

  static String _defaultId() => const Uuid().v4();

  final DraftEntryWriter _writer;
  final MediaPickerService _mediaPicker;
  final LocationService _locationService;
  final ActivityMetadataService _activityService;
  final SystemPermissionClient _permissions;
  final String Function() _newId;

  Future<ImportResult> importRecentPhoto({
    required TimeOfDayPrompt prompt,
    required SoftConsent requestSoftConsent,
  }) async {
    if (!await requestSoftConsent(SoftPermissionKind.photos)) {
      return const ImportCancelled();
    }
    final permission = await _permissions.request(SoftPermissionKind.photos);
    final blocked = _permissionFailure(permission, photos: true);
    if (blocked != null) return blocked;

    final asset = await _mediaPicker.fetchMostRecentAsset();
    if (asset == null || asset.localPath.trim().isEmpty) {
      return const ImportFailed(RichImportCopy.photosMissing);
    }

    final now = DateTime.now().toUtc();
    final id = _newId();
    final transcript = _transcript(
      prompt,
      'A recent photo is attached. The file stays on this device.',
    );
    final filename = asset.filename ?? p.basename(asset.localPath);
    final entry = _entry(
      id: id,
      createdAt: now,
      transcript: transcript,
      captureSource: 'rich_import_photo',
      captureContextTag: 'recent_photo',
      imageEvidence: ImageEvidence(
        evidenceId: _newId(),
        caption: 'Recent photo',
        mimeType: asset.mimeType.trim().isEmpty ? 'image/jpeg' : asset.mimeType,
        attachedAt: now,
        filename: filename,
        source: 'gallery_recent',
        localPath: asset.localPath,
      ),
    );
    return _save(entry);
  }

  Future<ImportResult> importCurrentLocation({
    required TimeOfDayPrompt prompt,
    required SoftConsent requestSoftConsent,
  }) async {
    if (!await requestSoftConsent(SoftPermissionKind.location)) {
      return const ImportCancelled();
    }
    final permission = await _permissions.request(SoftPermissionKind.location);
    final blocked = _permissionFailure(permission, photos: false);
    if (blocked != null) return blocked;

    final place = await _locationService.reverseGeocodeCurrent();
    final neighborhood = place?.neighborhood.trim() ?? '';
    if (place == null || neighborhood.isEmpty) {
      return const ImportFailed(RichImportCopy.locationMissing);
    }

    final now = DateTime.now().toUtc();
    final entry = _entry(
      id: _newId(),
      createdAt: now,
      transcript: _transcript(prompt, 'Near $neighborhood.'),
      captureSource: 'rich_import_location',
      captureContextTag: _tag(neighborhood),
    );
    return _save(entry);
  }

  Future<ImportResult> importCurrentActivity({
    required TimeOfDayPrompt prompt,
    required Future<ActivityMetadata?> Function() pick,
  }) async {
    ActivityMetadata? detected;
    try {
      detected = await _activityService.detectCurrent();
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'activity_detect_fallback_to_pick',
        name: 'EntryController',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final metadata = detected ?? await pick();
    final label = metadata?.label.trim() ?? '';
    if (metadata == null || label.isEmpty) return const ImportCancelled();

    final now = DateTime.now().toUtc();
    final entry = _entry(
      id: _newId(),
      createdAt: now,
      transcript: _transcript(prompt, 'Current activity: $label.'),
      captureSource: 'rich_import_activity',
      captureContextTag: _tag(label),
    );
    return _save(entry);
  }

  ImportFailed? _permissionFailure(
    PermissionOutcome outcome, {
    required bool photos,
  }) {
    return switch (outcome) {
      PermissionOutcome.granted => null,
      PermissionOutcome.denied => ImportFailed(
        photos ? RichImportCopy.photosDenied : RichImportCopy.locationDenied,
      ),
      PermissionOutcome.unavailable => ImportFailed(
        photos
            ? RichImportCopy.photosUnavailable
            : RichImportCopy.locationUnavailable,
      ),
    };
  }

  Future<ImportResult> _save(JournalEntry entry) async {
    try {
      await _writer(entry);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'rich_import_draft_save_failed',
        name: 'EntryController',
        error: error,
        stackTrace: stackTrace,
      );
      return const ImportFailed(RichImportCopy.saveFailed);
    }
    return ImportCreated(entry);
  }

  JournalEntry _entry({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required String captureSource,
    required String captureContextTag,
    ImageEvidence? imageEvidence,
  }) {
    return JournalEntry.stored(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: CaptureVoicePersistence.estimatedDurationSeconds(
        transcript,
      ),
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: CaptureSaveMessages.savedPrivatelyOnDevice,
        repeatedSignal: '',
      ),
      sync: JournalSyncMetadata(createdAt: createdAt, entryId: id),
      display: JournalDisplayMetadata(
        captureSource: captureSource,
        captureContextTag: captureContextTag,
      ),
      proof: JournalProofData(imageEvidence: imageEvidence),
    );
  }

  String _transcript(TimeOfDayPrompt prompt, String detail) =>
      '${prompt.title}\n\n$detail';

  String _tag(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 80) return trimmed;
    return trimmed.substring(0, 80);
  }
}

final draftEntryWriterProvider = Provider<DraftEntryWriter>((ref) {
  final store = ref.watch(journalStoreProvider);
  return (entry) => store.save(entry, first25Source: 'rich_media_import');
});

final entryControllerProvider = Provider<EntryController>((ref) {
  return EntryController(
    writer: ref.watch(draftEntryWriterProvider),
    mediaPicker: ref.watch(mediaPickerServiceProvider),
    locationService: ref.watch(locationServiceProvider),
    activityService: ref.watch(activityMetadataServiceProvider),
    permissions: ref.watch(systemPermissionClientProvider),
  );
});
