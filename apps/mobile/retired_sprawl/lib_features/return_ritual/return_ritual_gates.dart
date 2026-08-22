/// Entry-count and surface gates for the return ritual card.
abstract final class ReturnRitualGates {
  ReturnRitualGates._();

  static bool showOnArchive({required int entryCount}) => entryCount >= 1;

  static bool showOnRecord({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
    required bool isReadyOrIdle,
  }) => loaded && entryCount >= 1 && !isPostSave && isReadyOrIdle;
}