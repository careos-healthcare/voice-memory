> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# docs/history

Everything in this folder is superseded. It is kept so the reasoning behind
past decisions stays readable, not because it describes the product that ships
today.

## Rules for this folder

- Nothing here is authoritative. If a file here disagrees with
  `docs/current/`, `docs/current/` wins.
- Nothing here may be consumed by a release check, a validator, or a test.
- Nothing here may be linked from `docs/current/` as current documentation.
- Every file here starts with the non-authoritative banner shown above.
  `npm run test:docs-drift` fails if a file is missing it.

## Where current documentation lives

`docs/current/` holds the only authoritative documents:

- `PRODUCT_CONTRACT.md`
- `ARCHITECTURE.md`
- `DATA_FLOW_AND_PRIVACY.md`
- `MONETIZATION_CONTRACT.md`
- `RELEASE_CHECKLIST.md`
- `MIGRATIONS.md`
- `ACCESSIBILITY_DEVICE_VERIFICATION.md`
- `STORE_IDENTITY_CHECKLIST.md`

Machine-readable truth lives in `config/` and outranks all prose:

- `config/product/archive_me_v1_contract.json`
- `config/product/archive_me_v1_release_contract.json`
- `config/privacy/archive_me_data_flow.json`
- `config/monetization/archive_me_entitlement_matrix.json`
- `config/release/archive_me_identity.json`
- `config/release/archive_me_v1_backend_allowlist.json`

## Why files here contradict the shipping app

Most of these documents describe surfaces that were removed from the
commercial V1: the consumer web client, belief and trait systems, theory
tracking, blind spots, memory graphs, Life OS, life and horizon simulation,
live AI audio conversation, document ingestion, and broad archive synthesis.
Some also claim on-device-only processing, which is false — transcription and
interpretation are remote HTTP calls. Read them as history only.
