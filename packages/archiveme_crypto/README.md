# archiveme_crypto

**Status: prepared for future publication, not yet public.**

This package is complete in-tree and covered by its own test suite. It is
**not** a live release. The host repository stays private; `publish_to` stays
`"none"`. “You can audit this yourself” is a claim we will make when there is
a real user base at scale to trust — not before. A public repo also creates
maintenance obligations (security disclosures, compatibility promises, external
issues) that we will take on deliberately, not by default.

Local completeness is not a live release. Do not treat this tree as published.

## What this package does

ArchiveMe’s at-rest encryption and key-material handling — a crypto utility,
not product logic:

- AES-256-GCM for vault database bytes and private JSON envelopes
- 32-byte keys persisted by a host-supplied `KeyMaterialStore` (typically the
  platform keychain)
- Crash-safe JSON writes: encrypt → temp file → verify decrypt → last-known-good
  backup → atomic rename
- SQLCipher password material of that same class of key (v2 raw 32 bytes, or a
  legacy v1 passphrase)

Hosts implement encoding and any keychain prefix. This library does not depend
on the ArchiveMe app.

## What this package does not cover

The following stay closed. They are product logic, not this utility:

- Pattern detection
- Evidence matching / “tap a claim” citations
- On-device LLM, prompts, and analysis
- The iCloud vault pipeline, SQLCipher session lock, and app UI

This package does **not** prove that “everything stays on device.”

## Running the test suite independently

From this directory (Dart SDK only; no Flutter, no `apps/mobile`):

```bash
dart test
```

App-side Phase 0 goldens (`apps/mobile/test/fixtures/crypto_extract_goldens/`)
are a separate historical-byte lock. Do not recapture them. They are not
required to run this suite.

Fault-injection hooks are test-only: `package:archiveme_crypto/testing.dart`.

## License

MIT — see [LICENSE](LICENSE). Same class of license as a generic crypto
utility, not proprietary business logic.
