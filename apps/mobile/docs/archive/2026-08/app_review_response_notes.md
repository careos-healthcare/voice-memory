# ArchiveMe — App Review response notes

Use the text below in **App Review Information → Notes** when resubmitting ArchiveMe.

---

## Account

No account is required to use ArchiveMe. You can unlock full review access from
Settings without sign-in.

---

## Accessing full Pro features and sample archive (Guideline 2.1a)

To access all ArchiveMe Pro features and pre-populated sample archive entries
without a purchase:

1. Open **Settings** (Account tab).
2. Scroll to the **App Review Access** section (visible in this review build).
3. Enter this review code:

   **ARCHIVEME-REVIEW-2026**

4. Tap **Unlock Pro access**.

This activates:

- **Sample archive entries** with repeated patterns and archive proof visible
  in the Archive tab
- **ArchiveMe Pro** entitlement (loop maps, evidence, edits, return checks)
- No debug controls in the public release build

Alternative without the code: open **Sample Archive** from Settings (example data
only) or **Help & reviewer guide**.

---

## Subscription information (Guideline 3.1.2c)

The ArchiveMe Pro paywall shows all required auto-renewable subscription
information **before purchase**:

- **Product name:** ArchiveMe Pro
- **Plans:** Monthly or yearly auto-renewing subscription
- **Price:** Shown from App Store products when available; otherwise:
  "Purchases are not available right now." and "Monthly and yearly plans will
  appear when App Store products finish loading."
- **Auto-renewal:** Shown on paywall before purchase
- **Terms of Use:** https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- **Privacy Policy:** https://careosapp.co.uk/archiveme-privacy

The paywall appears after completing the first activation loop, or when a gated
Pro feature is accessed, or from Settings → See Pro preview.

---

## Microphone (Guideline 5.1.1)

Before the system microphone permission dialog, the Record screen uses the button
**Use voice to record** — not Apple-style wording such as "Allow" or "OK".

Users can always choose **Type instead** if microphone access is unavailable.

---

## Links

- Privacy Policy: https://careosapp.co.uk/archiveme-privacy
- Terms of Use (Apple Standard EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Support: https://careosapp.co.uk/archiveme-support

---

## Before resubmitting (maintainer checklist)

1. **App Store Connect** — Privacy Policy URL must match
   https://careosapp.co.uk/archiveme-privacy (not the support page).
2. **TestFlight** — Open Settings → See Pro preview (or `/subscription`) and
   confirm monthly/yearly prices load from App Store products.
3. **Screenshot** — Regenerate the subscription screenshot from
   `/subscription-review-preview` after any paywall copy change.
4. **Reviewer path** — Use App Review Access code **ARCHIVEME-REVIEW-2026** so
   reviewers can evaluate Pro without purchase.
