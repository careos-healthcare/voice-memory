# ArchiveMe — Part 1: Product & Architecture

**Positioning:** A private change ledger that shows exactly what repeated, what changed, the words proving it, and lets the user correct the record.

**Product category:** Auditable personal change.
**Primary promise:** See what repeated. See what changed. Verify it in your own words.

The differentiator is *auditability*. Every claim the product makes about a user must be traceable to an exact quote from their own saved words, and must be correctable by them. This constraint drives nearly every architectural decision below.

---

## 1. System topology

| Component | Path | Role |
|---|---|---|
| **Flutter app** | `apps/voicememory_mobile` | The sole shipping client. ~734 Dart files. Owns capture, storage, the semantic engine, and all UI. |
| **Next.js backend** | `app/api`, `lib/server` | Thin services only: auth, transcription proxy, analysis proxy, billing, encrypted sync blobs. |
| **Contracts & guards** | `config/`, `scripts/` | Machine-readable release boundary plus the validators that enforce it. |
| **Evaluation tooling** | `tool/` | Fast diff-aware checks and the conclusion-quality harness. |
| **Docs** | `docs/current`, `docs/history` | 8 authoritative docs; 62 archived historical docs. |

**Critical fact:** the mobile app never calls the backend export route or the analytics funnel route. Export is entirely client-side. Analytics goes to Firebase via a typed facade. The backend is not on the critical path for the product's core value.

### Legacy surface
A Next.js consumer web client and a Capacitor Android project were removed. The backend and `config/` contracts remain. Guards exist specifically to stop the removed surfaces from returning.

---

## 2. The V1 contract system

The release boundary is data, not convention. `config/product/archive_me_v1_contract.json` declares what may exist:

```json
{
  "allowedPrimaryRoutes": ["/record", "/archive-belief", "/belief-changes", "/account"],
  "allowedSecondaryRoutes": ["/onboarding", "/quick-capture", "/entry/:id", "..."],
  "allowedFeatureModules": [
    "recording", "archive", "changes", "explainable_conclusion",
    "insight_feedback", "monetization", "transcription", "voice_capture"
  ],
  "allowedStartupServices": ["..."],
  "canonicalJournalModel": "...",
  "canonicalSyncRoute": "...",
  "prohibitedModulesAndCapabilityGroups": [
    "capacitor", "graph-sync", "health", "camera", "beliefs", "creator-demo"
  ]
}
```

It is mirrored in Dart at `lib/product/archive_me_v1_product_contract.dart` so the app and the build system agree on one definition.

### Enforcement

| Guard | Enforces |
|---|---|
| `scripts/validate-archive-me-v1-capabilities.mjs` | Manifest pointers, route lists, dependency allowlist, native permissions, no direct Firebase use |
| `scripts/check-backend-allowlist.mjs` | Only allowlisted API routes are addressable; also fails if `server.entry.ts` re-attaches a removed WebSocket upgrade |
| `scripts/build-server.mjs` | Rejects a production bundle containing held-out experimental symbols |
| `scripts/documentation-drift.test.ts` | Docs may not claim behaviour the runtime does not have |
| `test/v1_navigation_guard_test.dart` | Exactly four primary routes — blocks a fifth tab |
| `test/v1_shipping_graph_test.dart` | Router imports no prohibited module |

**Design principle for guards:** use explicit production path and route allowlists, never broad substring scans. A guard that fires on an innocent identifier that merely contains a common word is itself a defect.

---

## 3. Data model and the central correctness invariant

### Archive identity

Every piece of user content belongs to exactly one archive. Identity is resolved from authentication state and the presence of legacy data.

```dart
enum LocalArchiveOwnerKind { guest, authenticated, legacyUnclaimed }

enum LocalArchiveOwnershipState {
  active, locked, awaitingDecision, migrating, migrationFailed,
}

final class LocalArchiveIdentity {
  final String archiveId;
  final LocalArchiveOwnerKind ownerKind;
  final String? authenticatedSubjectId;
  final LocalArchiveOwnershipState ownershipState;
  final int schemaVersion;

  bool get mayRender =>
      ownershipState == LocalArchiveOwnershipState.active ||
      (ownerKind == LocalArchiveOwnerKind.legacyUnclaimed &&
          ownershipState == LocalArchiveOwnershipState.awaitingDecision);

  bool get maySync =>
      ownerKind == LocalArchiveOwnerKind.authenticated &&
      ownershipState == LocalArchiveOwnershipState.active &&
      authenticatedSubjectId?.trim().isNotEmpty == true;
}
```

`mayRender` and `maySync` **fail closed**: an archive in an unresolved state renders nothing and syncs nothing, rather than guessing.

### Physical partitioning

`ArchiveScopePaths` gives each archive its own directory, so isolation is a filesystem property rather than a query filter:

```dart
abstract final class ArchiveScopePaths {
  static String sanitize(String archiveId) =>
      archiveId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static String scopeDirectory({required String basePath, required LocalArchiveIdentity identity}) =>
      '$basePath/archives/${sanitize(identity.archiveId)}';

  static String journalPath({required String basePath, required LocalArchiveIdentity identity}) {
    if (identity.ownerKind == LocalArchiveOwnerKind.legacyUnclaimed) {
      return legacyJournalPath(basePath);
    }
    return '${scopeDirectory(basePath: basePath, identity: identity)}/journal_entries.json';
  }
}
```

### JournalStore — the canonical aggregate

`lib/storage/journal_store.dart` is the single source of truth for saved moments. Its ownership rules:

- `ownerArchiveId` is a **required** constructor parameter. No method may silently default to `owner = local`.
- Reads filter to the owning archive, so a foreign row present in a shared file is invisible.
- Writes **reject** a foreign entry with a `StateError`, but **preserve** foreign rows already on disk byte-for-byte — a partial migration must never destroy another owner's data.

```dart
List<JournalEntry> _visibleEntries(
  Iterable<JournalEntry> entries, {
  required bool includeDeleted,
}) => List<JournalEntry>.from(
  entries.where((entry) =>
      entry.ownerArchiveId == ownerArchiveId &&
      (includeDeleted || !entry.isDeleted)),
);

Future<void> _writeAll(List<JournalEntry> entries) async {
  final owned = entries.where((e) => e.ownerArchiveId == ownerArchiveId).toList();
  if (owned.length != entries.length) {
    throw StateError(
      'Refusing to write an entry owned by another archive into $ownerArchiveId.',
    );
  }
  // Rows belonging to another archive are retained byte-for-byte.
  final foreign = (_cache ?? const <JournalEntry>[])
      .where((e) => e.ownerArchiveId != ownerArchiveId).toList();
  // ... persist [...owned, ...foreign]
}
```

### Unclaimed content

Guest and legacy archives are never auto-claimed on sign-in. `ArchiveOwnershipDecisionService` surfaces a **content-free** summary (counts and date range only) and offers four choices: keep separate, move to this account, export, delete. Migration is transactional and idempotent, so an interrupted move resumes without duplicating.

---

## 4. Service composition and cold start

`lib/services/composition/v1_composition.dart` builds nine modules through a registry:

```dart
static const Set<String> moduleNames = {
  'core', 'account', 'recording', 'archive', 'changes',
  'privacy', 'monetization', 'analytics', 'sync',
};
```

Only what Record needs is on the cold-start path. A `DeferredStartupCoordinator` holds the rest — monetization/RevenueCat, the analytics provider, sync, and archive indexing — until after the first frame, so capture becomes interactive before background computation begins.

Startup sequence (`lib/startup/archive_me_startup.dart`): configure storage paths → purge stale temp audio → build services → migrate legacy audio → initialise the transcription scheduler → refresh the onboarding gate.

On the debug iOS simulator only, storage initialisation is deferred until after the first frame behind a splash, because simulator disk setup is slow enough to hurt the perceived launch.

---

## 5. Directory map

```
voice-memory/
├── apps/voicememory_mobile/          # THE SHIPPING APP
│   ├── lib/
│   │   ├── main.dart                 # entry; system chrome; API resolution
│   │   ├── startup/                  # cold-start sequencing
│   │   ├── router/app_router.dart    # go_router; initial location /record
│   │   ├── product/                  # Dart mirror of the V1 contract
│   │   ├── models/journal_entry.dart # canonical entry
│   │   ├── storage/journal_store.dart# canonical aggregate + isolation
│   │   ├── services/
│   │   │   ├── composition/          # 9 modules + deferred startup
│   │   │   └── analytics/            # typed catalog + facade
│   │   ├── features/
│   │   │   ├── archive_ownership/    # identity, scope paths, decisions
│   │   │   ├── recording/            # capture + post-capture disposition
│   │   │   ├── explainable_conclusion/ # THE SEMANTIC ENGINE
│   │   │   ├── changes/              # ChangeThread
│   │   │   ├── monetization/         # access policy, contextual paywall
│   │   │   └── insight_feedback/     # user corrections
│   │   ├── screens/ widgets/ theme/
│   └── test/                         # incl. adversarial isolation suite
├── app/api/                          # Next.js routes
├── lib/server/                       # backend services
├── config/product/ config/release/   # contracts
├── scripts/                          # validators & guards
├── tool/                             # fast checks + evaluation harness
└── docs/current/ docs/history/
```
