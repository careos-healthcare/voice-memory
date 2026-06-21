# ArchiveMe — App Review response notes

Use the text below in **App Review Information → Notes** when resubmitting ArchiveMe.

---

## Account

No account is required to use ArchiveMe. All core features work on-device without sign-in. You can complete the first loop map, save evidence, and explore the app immediately after install.

---

## Accessing full Pro features (Guideline 2.1a)

To access all ArchiveMe Pro features without a purchase:

1. Build/run the App Review build with `ARCHIVEME_APP_REVIEW_MODE=true` (this is enabled in the review build submitted to App Store Connect).
2. Open **Settings** (Account tab).
3. Scroll to the **App Review Access** section (visible only in the review build).
4. Enter this review code:

   **ARCHIVEME-REVIEW-2026**

5. Tap **Unlock Pro access**.

This activates the same local Pro entitlement used by a paid subscription, unlocking:

- Additional loop maps
- Unlimited evidence saves
- Additional node edits
- Additional return checks

No debug controls are exposed in the public release build.

---

## Subscription information (Guideline 3.1.2c)

The ArchiveMe Pro paywall now shows all required auto-renewable subscription information **before purchase**, in a **Subscription details** section that is always visible:

- **Product titles:** ArchiveMe Pro Monthly / ArchiveMe Pro Yearly
- **Duration:** Monthly plan renews every month; Yearly plan renews every year
- **Price:** Shown from the App Store product when available; otherwise “Price shown by Apple at purchase.”
- **Auto-renewal:** “Subscription renews automatically unless cancelled at least 24 hours before the end of the current period.”
- **Cancellation:** “Manage or cancel your subscription in your Apple ID subscription settings.”
- **Privacy Policy:** https://careosapp.co.uk/archiveme-privacy
- **Terms of Use (EULA):** https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

The paywall appears after completing the first activation loop, or when a gated Pro feature is accessed.

---

## Links

- Privacy Policy: https://careosapp.co.uk/archiveme-privacy
- Terms of Use (Apple Standard EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
