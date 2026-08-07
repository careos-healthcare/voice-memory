# ArchiveMe stabilization programme — implementation plan

Repository: `voice-memory-rc-validation-448a5332` (isolated worktree)  
Branch: `cursor/rc-validation-448a5332`  
HEAD: `81a76390` (2026-08-07)

## 1. Build baseline

| Item | Status | Notes |
|------|--------|-------|
| Flutter analyzer 0 errors / 0 warnings | **PASS** | `tool/validate_analyzer_baseline.sh` — 70 info (baseline 72) |
| Release-evidence contracts | **PASS** | `lib/features/release_evidence/`, `single_launch_checklist` |
| Delete-account scroll + a11y | **PASS** | 200%/300% widget tests + semantics labels |
| TestStorageSandbox | **PASS** | `test/support/test_storage_sandbox.dart` + test |
| Repository-cleanliness validator | **PASS** | `tool/validate_repository_cleanliness.sh` |
| Dart format check | **FAIL** | 123 files need formatting (not committed — disk constrained) |
| iOS simulator build | **EXTERNALLY BLOCKED** | Requires macOS + CocoaPods + ~2GB free disk |
| Android debug build | **FAIL** | Host disk full (`No space left on device` during Gradle JAR) |
| CI workflow | **PASS** | `.github/workflows/archiveme-stabilization.yml` |

## 2. Privacy contract

| Item | Status | Notes |
|------|--------|-------|
| Canonical contract module | **PASS** | `lib/security/privacy_contract.dart` |
| Copy policy guards | **PASS** | `privacy_copy_policy.dart` + consumer scan tests |
| Encrypted sync protocol | **PASS** | `lib/features/encrypted_sync/` + migration tests |
| Remote-processing consent | **PASS** | `RemoteProcessingConsentStore` + recovery gates |
| PostgreSQL TLS (production) | **PASS** | `lib/server/db.ts` + `validate:auth-security` |
| PrivacyInfo.xcprivacy / Android backup rules | **PARTIAL** | Exists; native validation in CI graph audit |
| Legacy plaintext migration | **PASS** | `legacy_plaintext_migration_service.dart` + tests |

## 3. Durability and sync

| Item | Status | Notes |
|------|--------|-------|
| Crash-safe encrypted writes | **PARTIAL** | Atomic write patterns in sync modules |
| Transactional journal batch APIs | **PARTIAL** | Batch merge/sync in encrypted coordinator |
| Incremental sync | **PASS** | `incremental_encrypted_sync_test.dart` |
| Drift/SQLite migration | **SCAFFOLD** | Interface + tables; production default not switched |
| AccountSessionScope | **PARTIAL** | Generation checks on critical paths |

## 4. Architecture reduction

| Item | Status | Notes |
|------|--------|-------|
| V1 router slimming | **PASS** | 32 routes, quarantine redirects |
| Research package quarantine | **PASS** | `packages/archiveme_research` |
| Record controller split (V1) | **PARTIAL** | V1 controllers wired; main file still large |
| AppServices.instance removal (V1 paths) | **PASS** | `validate_v1_production_graph.sh` audit |
| Staged startup | **PASS** | `V1StartupCoordinator` |

## 5. Launch-product focus

| Item | Status | Notes |
|------|--------|-------|
| V1 navigation guard | **PASS** | `v1_navigation_guard.dart` |
| V1 product spec + contract docs | **PASS** | `docs/V1_*.md`, `v1_launch_product_contract.dart` |
| Quarantined surfaces removed from prod graph | **PASS** | Commits `f58b360e`, `5ebf3d3e` |
| Paywall/trust copy aligned | **PASS** | 9-capability promise |

## Commits this session (not pushed)

| SHA | Message |
|-----|---------|
| `043f9599` | fix(mobile): resolve analyzer info findings and declare intl dependency |
| `81a76390` | fix(mobile): align encrypted backup privacy copy with copy policy |

## Validation matrix (local, 2026-08-07)

| Gate | Result |
|------|--------|
| `npm ci` | **PASS** |
| `npx tsc --noEmit` | **FAIL** (pre-existing TS errors in ws, live-audio, archive-proof-stories) |
| `npm run lint` | **FAIL** (176 errors, 263 warnings — pre-existing) |
| `npm run build:server` | **PASS** |
| `npm test` | **N/A** (no test script; use `validate:auth-security`) |
| `npm run validate:auth-security` | **PASS** |
| `flutter pub get` | **PASS** |
| `validate_analyzer_baseline.sh` | **PASS** (0 errors, 0 warnings, 70 info) |
| `dart format --set-exit-if-changed` | **FAIL** (123 files) |
| Focused stabilization tests (37) | **PASS** |
| `validate_v1_production_graph.sh` | **PASS** |
| `validate_repository_cleanliness.sh` | **PASS** |
| `flutter build apk --debug` | **FAIL** (disk full) |
| `flutter build ios --simulator` | **EXTERNALLY BLOCKED** (disk + pods) |
| Full `flutter test` | **NOT RUN** (~188 pre-existing failures documented) |

**Release-ready:** **NO** — mandatory local gates for format, Android build, and full test suite not green. Host disk at ~99% capacity blocks Gradle and concurrent Flutter test compilation.
