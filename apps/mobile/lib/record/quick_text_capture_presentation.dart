/// Whether typed capture should use the calm Record first-run layout.
bool resolveFocusedRecordTypeEntry(Object? extra) {
  if (extra is Map) {
    if (extra['entryId'] != null) return false;
    if (extra['captureModeId'] != null) return false;
    if (extra['showFirstUseWordingHelper'] == true) return false;
    if (extra['showGuidedExamples'] == true) return false;
    if (extra['allowQuietDaySave'] == true) return false;
    if (extra['focusedRecordTypeEntry'] == false) return false;
    return true;
  }
  return true;
}