# Archived web components

These React components were moved out of `components/` so the production marketing web build only compiles shells used by `app/`.

Production web is marketing, legal, support, and beta only — see `packages/shared/lib/site/web-public-production-routes.ts`.

Consumer UI components live under `_archived/` for reference alongside `archived-consumer-routes/`. The mobile Flutter app at `apps/mobile` is the consumer product.

## Still live in `components/`

- `SiteFooter.tsx`, `SiteHeader.tsx`
- `layout/` — page landmarks
- `providers/` — visual tone provider
- `trust/` — legal/support page shell
