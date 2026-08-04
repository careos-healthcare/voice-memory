/// When to ask for email — value protection only, not app entry.
enum AuthTriggerReason {
  protectArchive,
  proPaywall,
  syncArchive,
  export,
  crossDevice,
  firstWorkingBelief,
  archiveChangedReturn,
  keepTrackingPro,
}

class AuthTriggerCopy {
  const AuthTriggerCopy({
    required this.title,
    required this.lead,
    required this.cta,
  });

  final String title;
  final String lead;
  final String cta;
}

bool shouldPromptForReflectionCount({
  required AuthTriggerReason reason,
  required int reflectionCount,
  required bool isSignedIn,
}) {
  if (isSignedIn || reflectionCount < 1) return false;
  if (reason == AuthTriggerReason.firstWorkingBelief) {
    return reflectionCount >= 5;
  }
  return true;
}
