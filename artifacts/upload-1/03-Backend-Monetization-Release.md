# ArchiveMe — Part 3: Backend, Monetization, Privacy & Release

---

## 1. Backend API surface

Next.js App Router, `runtime = "nodejs"`. Thin services only — the product's value is computed on-device.

| Group | Routes |
|---|---|
| Auth | `/api/auth/send-code`, `/verify`, `/session`, `/signout` |
| Capture | `/api/transcribe` (Whisper), `/api/analyze` (gpt-4o-mini), `/api/capture/attest` |
| Sync | `/api/sync/push`, `/api/sync/pull`, `/api/sync/manifest` |
| Billing | `/api/billing/checkout`, `/config`, `/entitlements`, `/webhook`, `/revenuecat/link`, `/revenuecat/webhook` |
| Account | `/api/account/delete`, `/api/user/subscription-status` |
| Journal | `/api/journal`, `/api/journal/[id]`, `/api/journal/export` |
| Ops | `/api/health`, `/api/healthz`, `/api/push/register`, `/api/internal/*` |

Two experimental WebSocket surfaces (`/api/live-audio/ws`, `/api/sync-relay/ws`) are **CLOSED**: handlers removed from `app/api`, upgrade calls detached from `server.entry.ts`, with guards in `check-backend-allowlist.mjs` and `build-server.mjs` that fail if either returns.

### Cross-account write defence

The session is always authoritative. This adds a *declared binding* so a request queued before an account switch cannot land in the new account.

```ts
export const OWNER_SCOPE_MISMATCH = "OWNER_SCOPE_MISMATCH" as const;
export const EXPECTED_ACCOUNT_HEADER = "x-vm-expected-account-id";
export const EXPECTED_ARCHIVE_HEADER = "x-vm-expected-archive-id";

export interface OwnerScopeRejection {
  code: typeof OWNER_SCOPE_MISMATCH;
  status: 409;
  message: string;
  /** Metadata only — never the rejected content. */
  log: { declaredAccountPresent: boolean; archiveScoped: boolean };
}

/**
 * Returns a rejection when the client's declared account does not match the
 * authenticated subject. A request that declares nothing is accepted and
 * remains constrained by the session alone.
 */
export function checkOwnerScope(
  claim: OwnerScopeClaim,
  sessionUserId: string,
): OwnerScopeRejection | null {
  const declared = claim.expectedAccountId?.trim();
  if (!declared) return null;
  if (declared === sessionUserId) return null;
  return {
    code: OWNER_SCOPE_MISMATCH,
    status: 409,
    message: "This request was prepared for a different account and was not applied.",
    log: { declaredAccountPresent: true, archiveScoped: Boolean(claim.expectedArchiveId) },
  };
}
```

Checked in `/api/sync/push` **before a single blob is read**. A forged claim can only ever *narrow* scope, never widen it. The client supplies the binding from `SyncService`.

---

## 2. Privacy posture — stated accurately

Honesty here is a product feature, and two claims were explicitly corrected because they were false:

| Aspect | Accurate statement |
|---|---|
| Local at-rest | AES-GCM encrypted (`EncryptedJsonFileStore`) |
| Audio | Sealed in an encrypted on-device vault (`AudioVaultService`) |
| Sync | Client-side encrypted with a **device-held key**. **NOT end-to-end** — no key escrow or recovery exchange |
| Processing | **NOT local-only**. Transcription and interpretation are remote when the user chooses Online |
| On-device | Available where the platform supports it; the user can choose it |

`scripts/documentation-drift.test.ts` (29 tests) fails the build if any document claims E2EE or local-only processing.

### Product copy guards
`consumer_copy_banned_words_test.dart`, `consumer_visible_branding_test.dart`, `privacy_copy_policy_test.dart`, `no_cloud_processing_copy_test.dart`. Notably **"journal" is a banned consumer word** — the approved term is *private change ledger*. Forbidden as primary positioning: AI journal, AI that remembers/knows you, personalised insights, ask your history anything, life operating system, hidden truth, therapy, diagnosis, personality analysis. "AI" stays secondary and factual.

---

## 3. Analytics — structural only

One typed facade. Direct Firebase use is blocked by test. Every event passes id allowlisting, sensitive-key rejection, property-key allowlisting, value allowlisting, bucketing of numerics, token-safety checks, and a 25-property cap. In debug a violation **throws**; in release it is dropped and counted.

Registered V1 events include the structural funnel:

```
first_capture_started, first_capture_saved, transcript_reviewed,
first_valid_observation_delivered, interpretation_feedback_submitted,
second_entry_saved, first_valid_comparison_delivered, changes_opened,
change_thread_opened, weekly_review_opened, paywall_shown_after_value,
purchase_started, purchase_completed, restore_completed, export_completed
```

Safe property vocabulary — values are bands and enums, never raw numbers or text:

```dart
static const Set<String> performanceDurationBands = {
  'under_200ms', 'under_500ms', 'under_1s', 'under_2s', 'under_5s', 'over_5s',
};
static const Set<String> timeBands = {
  'same_session', 'within_24h', 'within_72h', 'within_7d', 'over_7d',
};
static const Set<String> feedbackChoices = {
  'accurate', 'wrong_angle', 'too_generic', 'hide',
};
static const Set<String> accessDecisions = {
  'allowed', 'denied_pro_required', 'denied_quota', 'denied_not_eligible',
};
static const Set<String> subscriptionStates = {
  'free', 'pro_active', 'pro_expired', 'pro_grace',
};

/// Maps a measured duration onto a band. Kept beside the allowlist so the
/// two cannot drift apart.
static String durationBand(Duration value) {
  final ms = value.inMilliseconds;
  if (ms < 200) return 'under_200ms';
  if (ms < 500) return 'under_500ms';
  if (ms < 1000) return 'under_1s';
  if (ms < 2000) return 'under_2s';
  if (ms < 5000) return 'under_5s';
  return 'over_5s';
}
```

**Never sent:** transcript, quote, topic, thread label, structured-marker content, correction text, prompt, generated question, conclusion wording, or any inferred sensitive category.

A heuristic blocks any event id containing content-like substrings. `transcript_reviewed` collides on the word "transcript" despite carrying none, so it is handled by a single named exemption rather than by weakening the heuristic:

```dart
/// The content-marker heuristic exists to catch unreviewed strings that may
/// carry user text. A curated V1 event id is a fixed constant that has been
/// read by a human, so a substring collision in the *name* is not evidence of
/// a leak. Exemptions are listed one by one and never widened to a pattern.
static const Set<String> _contentMarkerExemptEventIds = {
  'transcript_reviewed',
};
```

---

## 4. Monetization

`AccessPolicyEngine` is the single authority. Capabilities are classified, not checked ad hoc.

```dart
abstract final class AccessPolicyEngine {
  static AccessDecision decide({
    required CapabilityId capability,
    required EntitlementSnapshot entitlement,
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
  }) {
    final policy = MonetizationPolicy.capability(capability);
    if (capability == CapabilityId.readExistingGeneratedOutput) {
      return AccessDecision.allow(AccessDecisionReason.existingGeneratedOutput);
    }
    if (policy.accessClass == AccessClass.userOwned) {
      return AccessDecision.allow(AccessDecisionReason.userOwned);
    }
    if (policy.accessClass == AccessClass.freeProof) {
      if (productValue.hasGenerated(capability)) {
        return AccessDecision.deny(AccessDecisionReason.alreadyGenerated);
      }
      // ... metered or allowed
    }
    if (policy.accessClass == AccessClass.pro) {
      return entitlement.hasProAccess
          ? AccessDecision.allow(AccessDecisionReason.proEntitled)
          : AccessDecision.deny(_proDenialReason(entitlement));
    }
    // proMetered / metered ...
  }
}
```

Access classes: `userOwned` (never paywalled), `freeProof` (one free demonstration), `pro`, `proMetered`, `metered`.

Two rules matter commercially:

- **`readExistingGeneratedOutput` is always allowed.** Something already generated for a user cannot be taken back behind a paywall when a subscription lapses.
- **Export is `userOwned`** and listed in `ContextualPaywallPolicy.neverPaywalled`. A user's own words are never held hostage.

**Free value is earned by delivery, not entry count.** `ProductValueDeliveryLedger` records `observation` / `comparison` only once the value was generated, semantically entailed, validated, persisted **and rendered**. The paywall appears only after real proof was delivered, and shows a safe count or a *user-confirmed* thread label — never an inferred one.

---

## 5. Testing and verification

`tool/run_fast_v1_checks.sh` is diff-aware: it formats changed Dart files, maps changed paths to the focused suites that cover them, runs `flutter analyze`, then the architecture guards, and runs TypeScript checks only when backend files changed. It treats a timeout and a test-loader crash as failures, because a host that dies during loading can still print a success-looking tail.

Key suites:

| Suite | Covers |
|---|---|
| `archive_account_isolation_test.dart` | 19 adversarial cross-account cases |
| `semantic_conclusion_gate_test.dart` | Rejection taxonomy and derived confidence |
| `change_thread_projection_test.dart` | Threads, corrections, label confirmation |
| `post_capture_disposition_test.dart` | Audio survives every disposition |
| `accessibility_matrix_test.dart` | Device × brightness × text-scale (to 2.0) × reduced motion |
| `product_analytics_test.dart` | No content escapes the facade |
| `documentation-drift.test.ts` | Docs match runtime |
| `owner-scope-guard.test.ts` | Cross-account write rejection |

### Known state
- `remote_transcription_disclosure_dialog_test.dart` hangs during full runs (pre-existing).
- `PrivateDataService.purgeStaleOnStartup` is defined but never called; its test fails honestly rather than being suppressed.
- 42 validators guarding the deleted web client were unwired from `npm run validate`; their definitions remain and the removal is recorded in `config/release/archive_me_v1_backend_allowlist.json`.

---

## 6. Honesty rules encoded in the build

These are enforced, not aspirational:

1. Unmeasured metrics read **`NOT YET MEASURED`** — never zero, because zero is a measurement claim.
2. Manual protocols read **`NOT EXECUTED`** until genuinely performed. No physical-device, TestFlight, or Play Internal result may be asserted from a simulator.
3. Synthetic evaluation fixtures are never described as human-validated, and live in a separate directory from `human_labels/`.
4. No "validated" product status without real retained users and real payments.
5. Performance budgets must derive from measurements, not from invented targets.

The conclusion evaluation harness (`tool/conclusion_evaluation/`) scores related-pair precision and recall, conclusion-kind precision, change-direction accuracy, dimension accuracy, unsupported-claim rate, wrong-domain rate, generic-output rate, suppression rate, and exact-evidence validity — with **precision weighted above recall**, because a confident wrong claim about someone's life is far more damaging than a missed one.
