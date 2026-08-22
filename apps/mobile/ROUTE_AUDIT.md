# Route audit — ArchiveMe mobile

Source: `lib/router/app_router.dart`, `lib/config/production_navigation.dart`, `lib/router/developer_route_guard.dart`.

## Active user-facing routes (production shell)

| Route | Purpose |
|-------|---------|
| `/record` | Record tab (default) |
| `/archive-belief` | Archive / Patterns tab |
| `/account` | Account tab |
| `/settings` | Settings |
| `/privacy`, `/terms`, `/about` | Trust / legal |
| `/subscription`, `/pricing`, `/restore-purchases` | Billing surfaces |
| `/entry/:id` | Entry detail |
| `/belief-evidence`, `/weekly-archive-review`, `/insight-quality` | Archive features |
| `/help-reviewer-guide` | App Store reviewer guide |
| `/pro-preview` | Pro value preview (no purchase CTA) |
| `/support-feedback` | Support |
| `/sample-archive` | Sample Archive demo (no private entries) |

## Sample / demo / reviewer routes

| Route | Notes |
|-------|-------|
| `/sample-archive` | Demo data only; consumer-reachable from Archive Home |
| `/sample-archive/context/:tagId` | Demo context drilldown |
| `/help-reviewer-guide` | Reviewer path; always in Settings |
| `/pro-preview` | Preview Pro value; dismissible |

## Dev / verification routes (release-hidden)

Blocked in release unless developer settings unlocked (7-tap version). Deep links redirect to `/settings` or `/record`.

| Route | Purpose |
|-------|---------|
| `/revenuecat-verify` | RevenueCat QA |
| `/restore-production-verify` | Restore QA |
| `/developer-diagnostics` | Diagnostics |
| `/first-pattern-quality` | Internal QA |
| `/trial-control` | Trial mode control |
| `/native-push-verify`, `/offline-sync-verify` | Infra QA |

Also gated: `/archive-analyst`, `/archive-deep-dive`, `/journal`, `/archive-journey`, `/blind-spots`, `/archive-tool/*`, and other deep archive tools.

## Legacy redirects (production)

| Old path | Redirect |
|----------|----------|
| `/timeline`, `/search`, `/discover`, `/memory` | `/archive-belief` |
| `/discover-changes`, `/archive-detail` | `/archive-belief` |

## Trial mode whitelist

When `ARCHIVEME_TRIAL_MODE=true`, only core tabs + help/support/entry routes are allowed; others redirect to `/record`.

## Launch rule

Production navigation (`ProductionNavigation.isNavRouteVisible`) must not promote dev/verification or deferred archive-tool routes. Sample Archive, Help, Support, Pro Preview, and Restore purchases remain reachable from Settings or Archive Home — not from hidden QA routes.
