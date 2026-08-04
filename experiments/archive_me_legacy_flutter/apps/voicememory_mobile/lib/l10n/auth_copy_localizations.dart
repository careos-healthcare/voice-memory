import '../auth/auth_trigger_rules.dart';
import 'generated/app_localizations.dart';

extension AuthCopyLocalizations on AppLocalizations {
  AuthTriggerCopy authTriggerCopy(AuthTriggerReason reason) {
    return switch (reason) {
      AuthTriggerReason.protectArchive => AuthTriggerCopy(
        title: authTriggerProtectArchiveTitle,
        lead: authTriggerProtectArchiveLead,
        cta: authTriggerProtectArchiveCta,
      ),
      AuthTriggerReason.syncArchive => AuthTriggerCopy(
        title: authTriggerSyncArchiveTitle,
        lead: authTriggerSyncArchiveLead,
        cta: authTriggerSyncArchiveCta,
      ),
      AuthTriggerReason.export => AuthTriggerCopy(
        title: authTriggerExportTitle,
        lead: authTriggerExportLead,
        cta: authTriggerExportCta,
      ),
      AuthTriggerReason.proPaywall => AuthTriggerCopy(
        title: authTriggerProPaywallTitle,
        lead: authTriggerProPaywallLead,
        cta: authTriggerProPaywallCta,
      ),
      AuthTriggerReason.crossDevice => AuthTriggerCopy(
        title: authTriggerCrossDeviceTitle,
        lead: authTriggerCrossDeviceLead,
        cta: authTriggerCrossDeviceCta,
      ),
      AuthTriggerReason.firstWorkingBelief => AuthTriggerCopy(
        title: authTriggerFirstWorkingBeliefTitle,
        lead: authTriggerFirstWorkingBeliefLead,
        cta: authTriggerFirstWorkingBeliefCta,
      ),
      AuthTriggerReason.archiveChangedReturn => AuthTriggerCopy(
        title: authTriggerArchiveChangedReturnTitle,
        lead: authTriggerArchiveChangedReturnLead,
        cta: authTriggerArchiveChangedReturnCta,
      ),
      AuthTriggerReason.keepTrackingPro => AuthTriggerCopy(
        title: authTriggerKeepTrackingProTitle,
        lead: authTriggerKeepTrackingProLead,
        cta: authTriggerKeepTrackingProCta,
      ),
    };
  }
}
