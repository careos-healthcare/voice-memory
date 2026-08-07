# ArchiveMe — backend & web services

**ArchiveMe's canonical consumer product is the Flutter mobile app** at
[`apps/voicememory_mobile`](./apps/voicememory_mobile). This root-level Next.js
project is **not** a second consumer app — it exists only to support the
mobile app and the business around it:

- Authenticated API/backend services the mobile app calls (transcription,
  analysis, account, sync, deletion/export endpoints, etc.)
- Privacy, terms, and support pages
- Necessary marketing/download pages (pointing users to the app stores)
- Server-side operational tooling (admin scripts, jobs, migrations)

There is one product promise, and it should read the same whether you're in
the app, on a marketing page, or in privacy copy:

> **Record a real moment, preserve the evidence, and safely see what changed
> over time.**

If you're looking for the consumer product itself — recording, the Archive,
proof/evidence display, correction controls, subscription — that all lives in
the Flutter app under `apps/voicememory_mobile`. See its
[README](./apps/voicememory_mobile/README.md) for how to run it.

## Stack

- Next.js (App Router)
- TypeScript
- Tailwind CSS

## Getting started

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Project structure

```
app/          # API routes, and the support/marketing/legal web pages
components/   # UI components for the web pages above
lib/          # Backend/server utilities and core logic shared with the API
data/         # Local data (gitignored when populated)
public/       # Static assets
apps/voicememory_mobile/   # The canonical consumer product (Flutter)
```
