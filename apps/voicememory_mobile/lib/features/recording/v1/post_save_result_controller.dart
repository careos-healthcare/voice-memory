/// Post-save verified result visibility for Record.
class PostSaveResultController {
  bool showPostSave = false;
  bool hasVerifiedProof = false;
  String? savedEntryId;
  String? localSaveTitle;

  void markLocallySaved({required String entryId, String? title}) {
    savedEntryId = entryId;
    localSaveTitle = title;
    showPostSave = true;
  }

  void markVerifiedResult() {
    hasVerifiedProof = true;
    showPostSave = true;
  }

  void reset() {
    showPostSave = false;
    hasVerifiedProof = false;
    savedEntryId = null;
    localSaveTitle = null;
  }
}
