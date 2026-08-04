# Unit economics production activation

Run these steps from a trusted deployment shell after sourcing production environment variables. The commands never need a database URL argument.

1. Set `DATABASE_URL`, `VOICEMEMORY_UNIT_ECONOMICS_HMAC_ACTIVE_VERSION`, its matching versioned HMAC key, `VOICEMEMORY_UNIT_ECONOMICS_PRICING_REQUIRED=true`, and a high-entropy `CRON_SECRET`.
2. Review `config/unit-economics/pricing-catalog.v1.json` against current vendor invoices/contracts. Its bundled values are dated assumptions, not guaranteed current prices. Copy it to a new versioned file and set `VOICEMEMORY_UNIT_ECONOMICS_PRICING_CATALOG_PATH` when changing any value; never mutate an activated version.
3. Run `npm run migrate:unit-economics`. It applies `docs/sql/004_unit_economics.sql` in one transaction and exits nonzero unless all required tables, functions, triggers, and indexes exist.
4. Run `npm run activate:unit-economics-pricing`. It validates complete metric/resource coverage and inserts through the application pricing store, without an HTTP/debug endpoint.
5. Run `npm run validate:unit-economics`, `npm run validate:migrations`, and `npx tsc --noEmit`.
6. Set `VOICEMEMORY_UNIT_ECONOMICS_ENABLED=true` and deploy.
7. Require `/api/health` to return HTTP 200 before sending traffic. Missing durable storage, HMAC configuration, active catalog, or catalog coverage makes readiness return 503.
8. Confirm Vercel invokes `GET /api/internal/unit-economics/reconcile` daily with `Authorization: Bearer $CRON_SECRET`. The job snapshots yesterday's durable per-user storage footprint before rollups and threshold breaches.

Do not paste database URLs, HMAC keys, cron secrets, raw user identifiers, request bodies, or vendor response text into deployment logs or incident notes.
