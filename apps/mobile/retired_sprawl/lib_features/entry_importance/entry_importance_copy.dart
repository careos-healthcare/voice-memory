/// User-facing copy for entry importance markers.
abstract final class EntryImportanceCopy {
  EntryImportanceCopy._();

  static const markImportant = 'Mark important';
  static const importantLabel = 'Important';
  static const removeImportant = 'Remove important';
  static const markedSuccess = 'Marked important';

  static const List<String> all = [
    markImportant,
    importantLabel,
    removeImportant,
    markedSuccess,
  ];
}