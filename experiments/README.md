# experiments/

**This directory is excluded from the production build and must never register routes.**

Everything under `experiments/` is retained for reference and possible future
revival. None of it is part of the commercial ArchiveMe V1 release surface.

## Hard rules

1. **Never register a route from here.** Next.js discovers route handlers by
   walking `app/`. Nothing in `experiments/` is under `app/`, so nothing here is
   addressable. Do not re-export an experiment handler from a file under `app/`,
   and do not add a rewrite, redirect, or middleware entry that forwards to one.
2. **Never import from `experiments/` in shipping code.** Imports from `app/`,
   `components/`, `middleware.ts`, `server.entry.ts`, or any module reachable
   from them are forbidden. The only permitted importers are test and validator
   modules under `lib/reliability/`, `backend/**/*.test.ts`, and `scripts/`,
   which exist to keep the archived contracts honest and never run in
   production.
3. **Never add a dependency here that shipping code needs.** If shipping code
   starts needing something in `experiments/`, move that thing out first.

## Build exclusion

`experiments/` is excluded from the production surface in these places. If you
add a new build or deploy path, exclude it there too.

| Where | Mechanism |
| --- | --- |
| `tsconfig.json` | `exclude` contains `experiments/**` |
| `.vercelignore` | `experiments/` is not uploaded |
| `.dockerignore` | `experiments/` is not copied into the server image |
| `config/release/backend-capabilities.json` | `releaseInputs` does not list `experiments` |
| `config/release/archive_me_v1_backend_allowlist.json` | Routes here appear only under `removed`, never under `routes` |

## Contents

| Path | What it is |
| --- | --- |
| `backend/app/api/**` | Backend route handlers removed from the V1 release surface. The path under `backend/` mirrors the original repo-relative path exactly, so `experiments/backend/app/api/atmosphere/route.ts` was `app/api/atmosphere/route.ts`. |
| `archive_me_legacy_flutter/` | Archived Flutter surfaces outside the V1 shipping graph. |
| `archive_me_legacy_web/` | Archived Next.js web surfaces outside the V1 shipping graph. |

## Guard

`npm run check:backend-allowlist` enumerates every route file under `app/api`
and fails if any route is missing from
`config/release/archive_me_v1_backend_allowlist.json`. It also fails if a route
listed as `removed` reappears under `app/api`. Moving a handler back out of
`experiments/` without updating the allowlist is therefore a CI failure.
