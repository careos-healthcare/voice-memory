# Focused-beta final release gate

**Command:** `npm run release:gate-focused-beta`  
**Verify-only (no re-run checks):** `npm run release:verify-focused-beta`

The gate runner executes automated checks against the **current production graph and repo HEAD**, writes evidence under `release/evidence/gate_<id>.log`, updates `release/focused_beta_status.json`, and exits non-zero when release is blocked.

## Sections

| Section | Scope | Automated |
| --- | --- | --- |
| **A** Source/static | Production-graph analyzer, route/CTA integrity, customer language, logs, prefs policy, disabled-capability imports | Yes |
| **B** Behavior | Consent/network boundary, capture/archive/evidence/export tests, deletion | Yes |
| **C** Builds | Android APK, iOS release, web lint/test/build, security validators | Yes |
| **D** Artifact | Manifest permissions, entitlements, SDK gates, version/legal URLs | Yes |
| **E** Manual | Resilience, accessibility, TestFlight smoke, signing, sync device evidence | No — signed JSON required |

Options:

```bash
npm run release:gate-focused-beta -- --skip-builds   # skip Section C compile gates (local dev)
npm run release:gate-focused-beta -- --json            # append evaluation JSON
```

## Non-waivable gates

These may **not** use waivers: `remote_consent_no_network_evidence`, `sensitive_storage_scan`, `log_redaction`, `export_delete`, `a_route_cta_integrity`, `a_disabled_capability_imports`, `a_production_graph_analyzer`, `d_artifact_inspection`.

Manual Section E evidence must include: `success`, `build_number`, `commit_sha`, `tester`, `device`, `os`, `timestamp`, `attachment_path`. See [MANUAL_EVIDENCE_CHECKLIST.md](./MANUAL_EVIDENCE_CHECKLIST.md).

## Policy sources

- Decisions: [FOCUSED_BETA_DECISIONS.md](../docs/release/FOCUSED_BETA_DECISIONS.md)
- Data map: [ACTIVE_BETA_DATA_MAP.md](../docs/privacy/ACTIVE_BETA_DATA_MAP.md)
- Logging: [LOGGING_POLICY.md](../docs/privacy/LOGGING_POLICY.md)
- Customer language: [CUSTOMER_LANGUAGE.md](../docs/product/CUSTOMER_LANGUAGE.md)
- Evidence schema: [focused_beta_status.schema.json](./focused_beta_status.schema.json)
