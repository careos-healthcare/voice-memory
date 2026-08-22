# Focused-beta release manifest

Machine-readable source of truth for ArchiveMe focused-beta release gates.

## Files

| File | Role |
| --- | --- |
| `focused_beta_status.json` | Canonical gate statuses, identity, capability snapshot |
| `focused_beta_status.schema.json` | JSON Schema (validated with repo `ajv`) |
| `../generated/release-summary.md` | Generated release summary (do not edit) |
| `../generated/release-reviewer-checklist.md` | Generated reviewer checklist (do not edit) |

## Commands

```bash
npm run release:gate-focused-beta          # run automated gates A–D, update manifest, evaluate blockers
npm run release:gate-focused-beta -- --skip-builds   # skip Section C build gates (faster local dev)
npm run release:status                 # print summary + regenerate Markdown
npm run release:verify-focused-beta    # blocking verification (exit non-zero when blocked)
npm run release:device-evidence-guide  # TestFlight + offline-sync steps + blocker table
npm run release:preflight-ios          # focused suite + release iOS build (no upload)
npm run release:apply-device-evidence  # validators → update manifest gates (add --ios-only)
npm run test:release-focused-beta-status
```

Physical device evidence (TestFlight smoke, offline sync re-verification): see [DEVICE_EVIDENCE_RUNBOOK.md](./DEVICE_EVIDENCE_RUNBOOK.md) and [XCODE_TESTFLIGHT_UPLOAD.md](./XCODE_TESTFLIGHT_UPLOAD.md).

Release packaging (`release:package-focused-beta`) runs verification first and exits non-zero when blocked.

## Updating gates

1. Run the underlying validator or manual check.
2. Update the gate row in `focused_beta_status.json` with honest `status`, `recordedAt`, `commitSha`, `buildNumber`, and `evidencePath`.
3. Reconcile `identity.buildNumber` with `apps/mobile/pubspec.yaml`.
4. Run `npm run release:verify-focused-beta`.

Conditional gates (`sync`, `storeBilling`, `notifications`, `nativeExtensions`) follow the capability snapshot in the manifest, which must match `V1CapabilityRegistry` and the production router.
