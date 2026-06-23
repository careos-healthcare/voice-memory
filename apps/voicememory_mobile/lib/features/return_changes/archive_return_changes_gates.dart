import 'archive_return_changes_engine.dart';

/// Visibility gates for the archive return-changes card.
abstract final class ArchiveReturnChangesGates {
  ArchiveReturnChangesGates._();

  static bool show({
    required int entryCount,
    required bool sampleMode,
    required ArchiveReturnChangesResult? result,
  }) =>
      entryCount >= 2 && !sampleMode && result != null;

  static bool showOnRecord({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
    required bool sampleMode,
    required ArchiveReturnChangesResult? result,
  }) =>
      loaded &&
      entryCount >= 2 &&
      !isPostSave &&
      !sampleMode &&
      result != null;
}
