# Manual protocols — billing

Part of [`MANUAL_TEST_PROTOCOLS.md`](MANUAL_TEST_PROTOCOLS.md). Not executed.

Covers protocols 9 to 13. **No purchase, renewal, restore, expiry, refund, or
revocation has been performed on any store, in sandbox or in production. There
is no revenue, no subscriber, and no transaction associated with this
repository. Any figure presented as coming from these protocols is fabricated.**

---

## Preconditions for every billing protocol

Facts these protocols depend on, read from the code rather than assumed:

| Thing | Value | Source |
| --- | --- | --- |
| Entitlement id | `archive_loop_pro` | `lib/features/monetization/domain/generated/monetization_policy.g.dart` |
| Accepted legacy alias | `pro` | same file |
| Offering packages | exactly one `monthly` and one `annual` | `lib/billing/revenuecat_configuration.dart` |
| Blocked package kind | `lifetime` | `monetization_policy.g.dart` |
| Monetization policy version | `2026-08-01` | `monetization_policy.g.dart` |
| iOS SDK key prefix | `appl_` | `revenuecat_configuration.dart` |
| Android SDK key prefix | `goog_` | `revenuecat_configuration.dart` |

Build with the billing defines. Only public SDK keys go here; a key starting
`sk_` is rejected by `validationErrorsFor` as `secret_key_forbidden`:

```bash
cd apps/voicememory_mobile
fvm flutter build ipa --release \
  --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
  --dart-define=REVENUECAT_SANDBOX_BUILD=true \
  --dart-define=STUDY_BUILD_SHA="$(git rev-parse HEAD)"

fvm flutter build appbundle --release \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY" \
  --dart-define=REVENUECAT_SANDBOX_BUILD=true \
  --dart-define=STUDY_BUILD_SHA="$(git rev-parse HEAD)"
```

Also required, and none of it exists yet as far as this repository can show:

1. An App Store Connect sandbox tester account, never a real Apple ID.
2. A Play Console licence-tester account on the internal track.
3. Both subscription products live in both stores, attached to the RevenueCat
   `current` offering as one monthly and one annual package.
4. Access to the RevenueCat dashboard for the project, to read customer state
   independently of what the app displays.

**Every step below must be run against sandbox or licence-tester accounts. Do
not use a real payment instrument.**

---

## 9. RevenueCat monthly

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Platform:      NOT EXECUTED
Store account: NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

Confirm a monthly subscription can be bought, that it grants exactly the
`archive_loop_pro` entitlement, and that it renews.

Run every step on iOS and again on Android; record two results.

### Steps

1. Sign in with a fresh account that has never purchased. Confirm the app
   reports no entitlement.
2. Open the paywall. Confirm exactly two options are offered — one monthly, one
   annual — and no lifetime option. More than one package of either kind fails
   `validateOffers` as `invalid_monthly_package_count`; record the code shown.
3. Confirm each price displayed is the localized store price, not a hard-coded
   string. Change the store account's region and confirm the displayed price
   changes with it.
4. Purchase the monthly package with the sandbox tester account.
5. Confirm the purchase completes and the app grants Pro without a restart and
   without a manual refresh.
6. In the RevenueCat dashboard, confirm the customer shows `archive_loop_pro`
   active, with a monthly product and the expected renewal date.
7. Force-quit and relaunch. Confirm Pro is still granted.
8. Put the device in airplane mode and relaunch. Confirm Pro is still granted
   offline and the app does not lock a paying subscriber out on a network
   failure.
9. Wait for one sandbox renewal cycle. Confirm the renewal happens and the
   entitlement does not lapse in between.
10. Confirm the server side agrees: the subscription status endpoint reports the
    same entitlement the app is showing. A disagreement between store, RevenueCat
    and server is a failure even if the app looks correct.

### Pass criteria

Steps 1–10 as described, on both platforms, with `archive_loop_pro` active
everywhere it is checked and one automatic renewal observed.

### Fail criteria

A purchase that takes payment without granting the entitlement; an entitlement
granted without a purchase; a lifetime package offered; a hard-coded price; Pro
lost on relaunch or offline; a renewal that does not occur; app, RevenueCat and
server disagreeing.

---

## 10. RevenueCat annual

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Platform:      NOT EXECUTED
Store account: NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Steps

1. Repeat protocol 9 steps 1–10 with the annual package, on a second fresh
   sandbox account that has never purchased.
2. Confirm the annual option displays its own localized price and its own
   renewal period, and that the two options are distinguishable without reading
   the price.
3. Confirm the annual purchase grants the same `archive_loop_pro` entitlement —
   not a different or additional one.
4. From an active monthly subscription, upgrade to annual. Confirm the
   entitlement is continuous with no gap and that the app never shows the user
   as unsubscribed during the change.
5. From an active annual subscription, downgrade to monthly. Confirm the change
   is scheduled at the period boundary and that Pro is retained until then.
6. Confirm the RevenueCat dashboard shows exactly one active entitlement after
   each change, never two overlapping ones.

### Pass criteria

Every step above, on both platforms, with a single continuous entitlement across
the upgrade and the downgrade.

### Fail criteria

Two overlapping entitlements; any gap in access during an upgrade; an early loss
of access during a downgrade; the annual purchase granting a different
entitlement id.

---

## 11. Restore

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Platform:      NOT EXECUTED
Store account: NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

A paying subscriber who reinstalls, or moves to a new handset, must get their
subscription back without contacting anyone. Both stores require a restore
control to exist and to work.

### Steps

1. With an active subscription from protocol 9, delete the app.
2. Reinstall and launch **without** signing in. Confirm the app does not claim
   Pro before any restore or sign-in.
3. Tap the restore control. Confirm it is reachable without signing in — a
   restore that requires an account is a review rejection risk and fails this
   step.
4. Confirm Pro is granted after the restore completes.
5. Sign in as the original account. Confirm Pro is still granted and that
   entitlement was not duplicated.
6. Tap restore again with nothing to restore, using a store account that has
   never purchased. Confirm the app says so plainly and does not error, hang, or
   grant anything.
7. Install on a second device with the same store account and restore there.
   Confirm Pro is granted on both devices.
8. Restore while offline. Confirm the app reports that it could not reach the
   store, and does not report that the user has no subscription.
9. Confirm restoring under store account X while signed into app account Y does
   not attach X's subscription to Y's data or expose any of Y's content to X.

### Pass criteria

Steps 1–9 as described, on both platforms, with step 6 giving a clear
no-purchases message and step 8 distinguishing "cannot reach the store" from
"you have no subscription".

### Fail criteria

Restore unavailable before sign-in; restore failing for a genuine subscriber;
"no subscription" shown when the real cause was a network failure; an
entitlement attached to the wrong account.

---

## 12. Expiry

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Platform:      NOT EXECUTED
Store account: NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

Confirm what a subscriber keeps when they stop paying. The policy is stated in
`monetization_policy.g.dart`: recordings stay theirs, and observations and
comparisons already created remain available. Expiry must remove future paid
capability, not confiscate past work.

Sandbox subscriptions renew on an accelerated clock; use it rather than waiting.

### Steps

1. Start from an active monthly subscription with at least five saved moments
   and at least one result created while subscribed.
2. Cancel the subscription in the store's manage-subscriptions screen. Confirm
   the app still grants Pro until the end of the paid period — cancelling is not
   expiring.
3. Let the period elapse.
4. Confirm the app now reports no entitlement, without requiring a reinstall.
5. Confirm every recording saved in step 1 is still present and still plays.
6. Confirm every result created in step 1 is still readable.
7. Confirm paid capability is now gated, and that the gate explains what expired
   rather than showing a generic error.
8. Confirm export still works, so a lapsed subscriber can take their own content
   with them.
9. Confirm the RevenueCat dashboard and the server subscription status both show
   the entitlement as inactive, in agreement with the app.
10. Resubscribe. Confirm access returns immediately and nothing was lost.

### Pass criteria

Access ends exactly at the period boundary, not before; every recording and
every previously created result survives steps 5, 6 and 8; resubscribing in step
10 restores access with no data loss.

### Fail criteria

Access lost at cancellation instead of at expiry; access retained after expiry;
any recording or previously created result becoming unreadable; export blocked
for a lapsed subscriber.

---

## 13. Refund / revocation

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Platform:      NOT EXECUTED
Store account: NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

A refund is not an expiry. It arrives out of band, from the store, with no user
action in the app, and it can arrive while the app is closed. Confirm the app
converges on the store's answer rather than trusting its own cached state.

### Steps

1. Start from an active subscription.
2. Trigger a refund or revocation from the store side: an App Store Connect
   sandbox refund, or a Play Console order refund with revocation on the
   licence-tester account.
3. Leave the app closed for the first hour after the refund. Then open it and
   confirm the entitlement is gone. An app that keeps granting Pro because it
   never re-checked has failed.
4. Confirm the RevenueCat dashboard shows the entitlement revoked and records
   the reason.
5. Confirm the webhook endpoint at `app/api/billing/revenuecat/webhook/route.ts`
   received the event and that the server's subscription status changed to
   match. If no webhook is configured for this environment, record that as a
   `BLOCKED` result rather than a pass.
6. Confirm the user's recordings and previously created results are all still
   present. A refund removes paid capability; it must not delete their content.
7. Confirm the app does not accuse the user of anything. The wording on losing
   access after a refund must be the same neutral wording used for expiry.
8. Repeat with the app in the foreground when the revocation lands. Confirm the
   change is picked up without a force-quit.
9. Resubscribe after the refund. Confirm the purchase succeeds and the
   entitlement returns.

### Pass criteria

Entitlement removed within one app launch of the revocation on both platforms;
store, RevenueCat, server and app all in agreement by the end of step 5; no
content lost; neutral wording; resubscribe works.

### Fail criteria

Pro still granted after a completed refund; content deleted as a consequence of
a refund; the server and the app disagreeing at the end of the run; accusatory
wording; a resubscribe that fails after a refund.
