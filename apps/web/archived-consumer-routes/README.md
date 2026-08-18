# Archived consumer web routes

These App Router segments were moved out of `app/` so Next.js does not compile or serve a parallel consumer product on the web.

Production web is marketing, legal, support, and beta only — see `packages/shared/lib/site/web-public-production-routes.ts`.

Internal, demo, and launch dashboards live under `archived-consumer-routes/` for local founder use only.

Production middleware still gates `/internal/*`, `/demo/*`, and `/launch/*` (404 without token/env). They are not compiled into the marketing web build.

The mobile Flutter app at `apps/mobile` is the consumer product.
