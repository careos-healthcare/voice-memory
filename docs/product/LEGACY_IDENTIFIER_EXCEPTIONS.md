# Legacy identifiers — intentional exceptions

Customer-visible copy uses **ArchiveMe**. These identifiers **must not** be renamed casually; they exist for store, OS, migration, and backend compatibility.

## Mobile (iOS / Android)

| Identifier | Value | Why it stays |
|------------|-------|--------------|
| Bundle ID | `com.voicememory.mobile` | App Store / Play listing, IAP, push, App Group |
| App Group | `group.com.voicememory.mobile` | WidgetKit shared container |
| URL scheme | `voicememory://` | Deep links, Shortcuts, existing installs |
| Dart package | `archiveme_mobile` (pub name) | Import graph; legacy folder `voicememory_mobile/` |
| Theme tokens | `VoiceMemoryColors`, `VoiceMemoryTypography`, `VoiceMemoryCards` | Internal only — never rendered as product name |
| Build flags | `VM_*`, `VOICE_MEMORY_*` | CI / flavor configuration |
| Deprecated bundle | `com.voicememory.app` | Must not reappear in active config |

## Backend / monorepo

| Identifier | Value | Why it stays |
|------------|-------|--------------|
| npm scope | `@voice-memory/*` | Package publishing |
| API route prefixes | `VoiceMemoryApiRoutes`, consent/onboarding API class names | Server contract |
| Database / migration keys | `voicememory_*` table or key names | Data migration safety |

## Email / domains

| Identifier | Customer-visible? | Notes |
|------------|-------------------|-------|
| `hello@archiveme.app` | **Yes** — primary contact | Web, app help, feedback |
| `support@archiveme.app` | **Yes** — billing alias | Forward to same inbox as hello@ |
| `hello@voicememory.app` | **No** — legacy inbound | Retire when forward unused |
| `voicememory.app` | **Redirect only** | Middleware 308 → archiveme.app; remove from Vercel after transition |
| `archiveme.app` | **Yes** — canonical marketing | Site, privacy, contact, store URLs |

## Routes (internal names, user sees labels)

| Route path | User-facing label |
|------------|-------------------|
| `/archive-belief` | Archive |
| `/belief-changes` | What is changing |
| `/belief-evidence` | Evidence |
| `/belief-detail` | Change detail |

Screen/widget class names (`BeliefChangesScreen`, `ArchiveBeliefScreen`, etc.) are implementation details — tests assert user outcomes and copy, not class names.

## Annotated copy-test allowlist

See `apps/mobile/test/customer_language_production_copy_test.dart` → `_annotatedLiteralAllowlist` for reviewed one-off exceptions (e.g. negative disclaimers containing "not therapy", deprecated `@Deprecated` aliases).
