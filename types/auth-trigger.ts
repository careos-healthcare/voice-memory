/** Why email sign-in is being offered — value protection, not app entry. */
export type AuthTriggerReason =
  | "protect_archive"
  | "pro_paywall"
  | "sync_archive"
  | "export"
  | "cross_device"
  | "first_working_belief"
  | "archive_changed_return"
  | "keep_tracking_pro";
