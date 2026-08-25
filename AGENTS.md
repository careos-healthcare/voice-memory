<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Cursor Cloud specific instructions

Node 22 + npm (see `package-lock.json`). Dependencies install with `npm install`. Standard commands live in `package.json` scripts and `README.md`; only the non-obvious gotchas are captured here.

### Running the web app (the product)
- Use `npm run dev:next` (plain `next dev`, port 3000) to run the full core product in dev mode.
- Do NOT use `npm run dev` in this environment. That is a custom Node server (`node --import tsx server.mjs`) and it crashes on boot: the live-audio import chain pulls in the `server-only` package, which throws when loaded by `tsx` outside a bundler. `npm run dev` only adds the optional Gemini live-audio WebSocket proxy, so `next dev` still serves the entire journaling product. Do not try to work around it with `node --conditions=react-server` — that resolves React to its react-server build for the whole process and breaks SSR (every page 500s).
- Set a ≥32-char `AUTH_SECRET` env var when starting the dev server (e.g. `AUTH_SECRET=dev-local-auth-secret-min-32-chars-long`). No Postgres is needed for local dev (auth/sync fall back to in-memory). `OPENAI_API_KEY` is only needed for live transcription/analysis (`/api/transcribe`, `/api/analyze`).

### Required local seed file (gitignored)
- `lib/social-proof/archive-proof-stories.ts` imports `@/data/archive-proof-stories.json` at build time, but `/data/*.json` is gitignored and this file is not in git history. Without it, `next dev` and `next build` fail with a module-not-found. The startup update script recreates it idempotently, so a fresh VM already has it; if you wipe `data/`, re-run the update script (or recreate the file) before starting the server.

### Exercising the product without a mic / API key
- The recorder needs a real microphone and `OPENAI_API_KEY`. To exercise the core loop without them, open `/demo` and click "Enter demo mode": it seeds ~13 pre-analyzed reflections into browser local storage, then Journal (`/journal`), Insights (`/insights`), and Search show real, analyzed data. Entries live in local storage per browser, so they are not visible via server-side/curl requests.

### Lint / test / build caveats
- `npm run lint` runs but currently reports many pre-existing errors/warnings unrelated to setup.
- `npm run build` currently FAILS on a pre-existing TypeScript error in `lib/live-audio/gemini-live-proxy.ts`; dev mode (`next dev`) is unaffected. `npm run test:e2e` runs `next build` first, so it inherits this failure until the type error is fixed.
- Unit/integration tests run through the Node test runner via `tsx` (e.g. `npm run test:research-evidence`) and the many `npm run validate:*` scripts.

### Mobile app
- `apps/voicememory_mobile` is a separate Flutter client (needs the Flutter SDK) and is not required to develop or run the web product.
