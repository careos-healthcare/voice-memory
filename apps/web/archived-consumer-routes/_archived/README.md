# Archived consumer web routes

These App Router segments were moved under `_archived/` so Next.js does not compile or serve a parallel consumer product on the web.

Production web is marketing, legal, support, and beta only — see `packages/shared/lib/site/web-public-production-routes.ts`.

The mobile Flutter app at `apps/mobile` is the consumer product.

Middleware returns **410 Gone** for retired consumer paths and **404** for unknown public paths.
