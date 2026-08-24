<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# ArchiveMe Monorepo Context

Read `apps/mobile/docs/V1_PRODUCT_CONTRACT.md` first — it defines the 9 launch capabilities and what's explicitly out of scope. Don't build outside that contract without being asked.

Before adding a new file to `apps/mobile/lib/features/`, `apps/mobile/docs/`, or `apps/mobile/tool/`: check `apps/mobile/.feature_count_budget` and `apps/mobile/tool/gates.yaml` — this repo enforces a hard cap on sprawl. Extend something existing before creating new.

`apps/mobile/retired_sprawl/` holds retired code, symlinked from `lib/features/` for compile safety. Never edit it, never treat it as live.
