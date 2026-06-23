/// Visibility gates for the moment quality coach.
abstract final class MomentQualityGates {
  MomentQualityGates._();

  static bool showForDraft(String text) => text.trim().isNotEmpty;

  static bool showForSavedMoment(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('[draft]')) return false;
    return true;
  }
}
