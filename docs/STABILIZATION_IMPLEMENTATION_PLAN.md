# ArchiveMe stabilization programme — implementation plan

Repository: `voice-memory` (Flutter mobile + Next.js server)  
Branch: `cursor/rc-validation-448a5332`  
Last updated: 2026-08-06

## 1. Build baseline

| Item | Status | Notes |
|------|--------|-------|
| Flutter analyzer 0 errors / 0 warnings | Done | `tool/validate_analyzer_baseline.sh` |
| Release-evidence contracts | Done | `lib/features/release_evidence/` present |
| Delete-account scroll + a11y | In progress | 200% test exists; 300% + copy fix pending |
| TestStorageSandbox | In progress | `test/support/test_storage_sandbox.dart` |
| Repository-cleanliness validator | In progress | `tool/validate_repository_cleanliness.sh` |
| iOS simulator build | Pending | macOS/CocoaPods reconcile |
| CI workflow | In progress | `.github/workflows/archiveme-stabilization.yml` |

## 2. Privacy contract

| Item | Status | Notes |
|------|--------|-------|
| Canonical contract module | In progress | `lib/security/privacy_contract.dart` |
| Copy policy guards | Done | `privacy_copy_policy.dart` + tests |
| Remote-processing consent | Done | P1 programme (`RemoteProcessingConsentStore`) |
| Account-scoped storage | Done | P1 programme (`AccountNamespace`) |

## 3. Durability and sync

| Item | Status | Notes |
|------|--------|-------|
| Journal copyWith / mutations | Done | P1 programme |
| Sync versioning + tombstones | Done | P1 programme |
| Server account deletion | Done | P1 programme + mobile delete flow |
| Offline vault recovery | Existing | tests in suite |

## 4. Architecture reduction

| Item | Status | Notes |
|------|--------|-------|
| V1 router slimming | Done | 32 GoRoutes, quarantine redirects |
| Research package quarantine | Done | `packages/archiveme_research` |
| Record controller split (V1) | Started | V1 controllers wired via delegation |

## 5. Launch-product focus

| Item | Status | Notes |
|------|--------|-------|
| V1 navigation guard | Done | `v1_navigation_guard.dart` |
| V1 product spec | Done | `docs/V1_PRODUCT_SPEC.md` |
| Post-save surface cap | Done | `surface_priority_engine.dart` V1 audit |

## Commit strategy

1. Functional fixes (delete-account copy, TestStorageSandbox, cleanliness gate)
2. Test migrations (timestamp JSON → sandbox)
3. Privacy contract + behavioral tests
4. CI workflow (no push)
5. Dart format-only commit (if needed, separate)
