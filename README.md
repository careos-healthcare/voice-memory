# ArchiveMe

**See what changed. Check the exact words and dates behind it. Correct anything
ArchiveMe gets wrong.**

A voice and text journal that saves the original moment first, then shows at most
one evidence-backed observation you can open, check, and correct.

## Where the documentation is

`docs/current/` holds the only authoritative documents. Start there.

| Document | What it settles |
| --- | --- |
| [`docs/current/PRODUCT_CONTRACT.md`](docs/current/PRODUCT_CONTRACT.md) | The promise, the loop, onboarding, confidence bands, and what is deliberately absent |
| [`docs/current/ARCHITECTURE.md`](docs/current/ARCHITECTURE.md) | Shipping boundary, storage, remote processing, sync, composition |
| [`docs/current/DATA_FLOW_AND_PRIVACY.md`](docs/current/DATA_FLOW_AND_PRIVACY.md) | Every data flow, what leaves the device, and the honest limits of the encryption |
| [`docs/current/MONETIZATION_CONTRACT.md`](docs/current/MONETIZATION_CONTRACT.md) | Entitlements, free proof, metered capabilities |
| [`docs/current/RELEASE_CHECKLIST.md`](docs/current/RELEASE_CHECKLIST.md) | Automated gates and the external blockers |
| [`docs/current/MIGRATIONS.md`](docs/current/MIGRATIONS.md) | One-way migrations that preserve installed-user access |
| [`docs/current/ACCESSIBILITY_DEVICE_VERIFICATION.md`](docs/current/ACCESSIBILITY_DEVICE_VERIFICATION.md) | Runnable real-device scripts, all currently `BLOCKED_EXTERNAL` |
| [`docs/current/STORE_IDENTITY_CHECKLIST.md`](docs/current/STORE_IDENTITY_CHECKLIST.md) | Bundle IDs, store product IDs, and the identity gate |

Machine-readable manifests in `config/` outrank all prose. Superseded documents
are retained in [`docs/history/`](docs/history/README.md), where every file
carries a non-authoritative banner. Nothing in there may be used for a release
decision.

## Repository layout

```
apps/voicememory_mobile/  # The shipping Flutter client
app/api/                  # The API-only Next.js backend
lib/                      # Backend and shared TypeScript logic
config/                   # Machine-readable product, privacy, release manifests
docs/current/             # Authoritative documentation
scripts/                  # Validators, generators, and guard tests
```

The Next.js application is an API-only backend artifact. The consumer web client
and the Capacitor shell are not part of the release graph.

## Getting started

Backend:

```bash
npm install
npm run dev
```

Shipping client (Flutter version is pinned by `.fvmrc`):

```bash
cd apps/voicememory_mobile
fvm flutter pub get
fvm flutter run
```

## Guard commands

```bash
npm run test:docs-drift            # docs/current matches how the app behaves
npm run test:v1-product-contract   # primary destinations and prohibited surfaces
npm run check:identity             # release identifiers agree with source
npm run check:backend-allowlist    # no unlisted backend route is addressable
npm run validate:backend-release   # migrations, billing, monetization contract
```
