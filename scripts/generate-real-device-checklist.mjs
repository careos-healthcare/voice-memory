#!/usr/bin/env node
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/real_device_runtime_proof_checklist.md",
);

const md = `# Real-device runtime proof checklist

Automated CI cannot replace on-device behavior. Run before major releases.

**Gate:** \`npm run validate:device-proof\`  
- Default: **DEVICE_BLOCKED** (exit 0, honest skip)  
- Release enforcement: \`VOICEMEMORY_DEVICE_PROOF_REQUIRED=1\` after completing sign-off below

## Devices & browsers

- [ ] iPhone Safari (latest iOS)
- [ ] Android Chrome (latest)
- [ ] iOS PWA installed to home screen
- [ ] Android PWA installed to home screen

## Core flows

- [ ] Microphone permission prompt and grant/deny paths
- [ ] Recording success (voice captured, transcript appears)
- [ ] Recording failure (permission denied, hardware error) — calm copy, recoverable
- [ ] Export (JSON and/or print path)
- [ ] Account deletion end-to-end (staging account)
- [ ] Auth magic link / email sign-in (staging Resend)

## Commerce (staging only)

- [ ] Stripe checkout opens and completes on test card
- [ ] Entitlement reflects after return (no live keys on dev machine)

## Accessibility & motion

- [ ] VoiceOver (iOS) or TalkBack (Android) quick pass on home, journal, memory
- [ ] Reduced motion enabled — no stuck invisible content
- [ ] 375px width — no horizontal scroll on Tier A/B/C routes

## Network & offline

- [ ] Slow 3G — record still usable or honest offline message
- [ ] Offline / local-only mode — recording and revisit without false sync promises

## Product trust

- [ ] Resurfacing feedback (helpful / not now) without nagging
- [ ] Crisis/safety page resources readable

## Sign-off

| Tester | Date | Build / commit | Notes |
|--------|------|----------------|-------|
|        |      |                |       |
`;

writeFileSync(out, md);
console.log(`Wrote ${out}`);
