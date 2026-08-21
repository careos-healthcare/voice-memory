# ArchiveMe — Known limitations (TestFlight beta)

Set expectations for testers and internal QA. These are **not** bugs unless they cause data loss, crashes, or misleading medical claims.

---

## Platform and data

| Limitation | What testers should know |
| --- | --- |
| **Local-first beta** | Moments are stored on device. This build is optimized for private, offline-first use. |
| **No cloud sync yet** | Reinstalling or switching devices may lose entries unless export/backup is used. |
| **No notifications yet (or limited)** | Reminders and push may be off or incomplete in early TestFlight builds. |
| **Backend dependency** | Voice transcription and some analysis need network; failures should show honest fallback, not fake success. |

---

## Product behavior

| Limitation | What testers should know |
| --- | --- |
| **2–3 real entries before value** | Repeat/proof surfaces may not appear after one generic entry. Same thread across entries matters. |
| **May not detect every pattern** | ArchiveMe uses evidence gates — weak or unrelated entries may not trigger cards. |
| **“May” language by design** | Summaries use cautious wording; absence of a card is not a clinical conclusion. |
| **Not every card on day one** | Quiet signal, what changed, review inbox, and beta mission appear only when gates pass. |
| **Typed entries valid** | Testers can use Type instead for faster QA; voice is not required. |

---

## Billing and TestFlight

| Limitation | What testers should know |
| --- | --- |
| **RevenueCat may be disabled in tests** | Internal test runs often skip billing; TestFlight may show inert paywall. |
| **Purchases may be unavailable** | Pro upgrade may not complete until App Store products are live. |
| **Restore purchases** | Button should remain visible and safe; restoring may return nothing in beta. |

**Do not** treat “purchase failed on TestFlight” as a launch blocker unless Restore crashes or misleads users.

---

## Out of scope for this beta wait period

The team is **not** adding features while waiting for Transporter upload. Feedback in these areas is logged for later:

- Cloud sync and multi-device  
- Push notification campaigns  
- AI chat expansion  
- New proof thresholds or evidence gates  
- Paywall redesign  

See [FEEDBACK_TRIAGE.md](./FEEDBACK_TRIAGE.md) and [BETA_RELEASE_STATUS.md](./BETA_RELEASE_STATUS.md).

---

## Safety wording

ArchiveMe is **not** medical or therapy advice. It does not diagnose, treat, or score mental health. Testers who need professional support should use qualified services, not this app.
