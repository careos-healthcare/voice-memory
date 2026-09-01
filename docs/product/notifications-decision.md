# Notifications decision

ArchiveMe should not request push notification permission before beta retention is proven.

For now, retention should come from in-app loops:
- Return Tomorrow Cue
- Yesterday Watch
- First Week Progress
- Weekly Archive Review

Only consider notifications after testers say they want reminders.

If added later, notifications must be:
- optional
- user-controlled
- quiet
- privacy-preserving
- never required for core use

`V1CapabilityRegistry.notifications` and `V1CapabilityRegistry.backgroundProcessing` stay `false`. That is the standing V1 cut, not an unbuilt default.

## Reconsidered 2026-09-01 — A reaffirmed

This was scoped again on 1 September 2026: ship no V1 notifications **(A)** versus one narrow, opt-in, evidence-based local notification **(B)**. The tradeoff was written out in full before choosing.

**A was reaffirmed.** Two reasons, beyond simplicity:

1. **B would not be new information.** Pattern detection runs in-session (Archive / Changes / pattern sheet, or at save). A later ping would remind the user of a finding they could already have seen. Narrow and evidence-based is not the same as genuinely new; B would be the latter dressed as the former, and that does not clear the bar set for a first notification.
2. **The documented revisit trigger has not fired.** Testers have not asked for reminders. Overriding a deliberate decision because the option was interesting to scope is not a reason to override it.

If this comes up again: a real decision was made, not silence. Revisit only when testers ask and in-app return loops are insufficient — the original trigger, still in force.
