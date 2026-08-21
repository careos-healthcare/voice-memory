# ArchiveMe — Safe sharing foundation

**Status:** Copy and strategy only — **no sharing feature is live.**

This folder defines how ArchiveMe may talk about future family, coach, or therapist-**adjacent** sharing without building send/export flows or making medical claims.

## Living docs

| File | Purpose |
| --- | --- |
| [SAFE_SHARING_PRINCIPLES.md](./SAFE_SHARING_PRINCIPLES.md) | Core principles: consent, privacy, reversibility |
| [NO_MEDICAL_CLAIMS_COPY_RULES.md](./NO_MEDICAL_CLAIMS_COPY_RULES.md) | Allowed vs banned consumer copy |

## Archived sharing materials

Future share report concepts and the risk register live in
[`../archive/2026-08/`](../archive/2026-08/).

## Code (copy/model only)

- `lib/features/safe_sharing/safe_sharing_copy.dart` — canonical allowed strings and banned terms
- `lib/features/safe_sharing/safe_sharing_model.dart` — foundation flags (no UI, no network)
- `test/safe_sharing_copy_test.dart` — copy guard tests

## Do not build yet

- Share links, invite flows, contact pickers
- Therapist/coach dashboards
- Automatic sharing or sync-backed sharing
- Any copy that implies diagnosis, treatment, or clinical records
