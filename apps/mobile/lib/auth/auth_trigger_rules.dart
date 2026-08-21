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

const authTriggerCopy = <AuthTriggerReason, AuthTriggerCopy>{
  AuthTriggerReason.protectArchive: AuthTriggerCopy(
    title: 'Protect this archive',
    lead:
        'Sign in with email to encrypt a backup of what you built on this device.',
    cta: 'Protect with email',
  ),
  AuthTriggerReason.syncArchive: AuthTriggerCopy(
    title: 'Back up your archive',
    lead: 'Email sign-in enables encrypted sync on this device.',
    cta: 'Sign in to sync',
  ),
  AuthTriggerReason.export: AuthTriggerCopy(
    title: 'Export with a protected account',
    lead: 'Sign in before exporting your archive.',
    cta: 'Sign in to export',
  ),
  AuthTriggerReason.proPaywall: AuthTriggerCopy(
    title: 'Sign in for Pro',
    lead: 'Checkout needs an account to protect your archive.',
    cta: 'Continue with email',
  ),
  AuthTriggerReason.crossDevice: AuthTriggerCopy(
    title: 'Continue on another device',
    lead: 'Sign in to pick up your archive where you left off.',
    cta: 'Sign in to continue',
  ),
  AuthTriggerReason.firstWorkingBelief: AuthTriggerCopy(
    title: 'Your archive has a working belief',
    lead: 'Sign in to protect the belief your archive is forming.',
    cta: 'Protect this belief',
  ),
  AuthTriggerReason.archiveChangedReturn: AuthTriggerCopy(
    title: 'See what your archive believes now',
    lead: 'Sign in to protect your archive after it may have shifted.',
    cta: 'Protect archive',
  ),
  AuthTriggerReason.keepTrackingPro: AuthTriggerCopy(
    title: 'Keep tracking with Pro',
    lead: 'Sign in before upgrading so your archive stays backed up.',
    cta: 'Sign in to continue',
  ),
};

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