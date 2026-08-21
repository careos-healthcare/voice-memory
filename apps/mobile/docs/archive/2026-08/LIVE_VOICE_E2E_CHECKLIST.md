# Live voice E2E verification checklist

Use this checklist on a **physical device** after automated tests pass. Do not use the pasted `GeminiLiveAudioSession` snippet — ArchiveMe uses the backend proxy stack under `lib/features/live_audio/`.

## Prerequisites

### Backend (repo root)

- [ ] `.env.local` contains `GEMINI_API_KEY` and `AUTH_SECRET` (min 32 chars)
- [ ] Server started with `npm run dev` (not `dev:next`)
- [ ] All pass:
  ```bash
  npm run validate:live-audio-protocol
  npm run validate:live-audio-session
  npm run validate:live-audio-ws
  ```

### Mobile

- [ ] Physical device on same LAN as dev machine
- [ ] Run with live flag and LAN backend URL:
  ```bash
  cd apps/mobile
  flutter run \
    --dart-define=ENABLE_LIVE_VOICE_CAPTURE=true \
    --dart-define=VOICE_MEMORY_API_BASE_URL=http://<LAN-IP>:3000
  ```
- [ ] Automated suite passes:
  ```bash
  flutter test test/features/live_audio/
  ```

## Happy path

- [ ] Open Record → tap record CTA
- [ ] Flutter logs show `ARCHIVEME_LIVE:` lines:
  - `session minted sessionId=... proxyUrl=ws://...sessionToken=%5Bredacted%5D`
  - `connect started`
  - `setupComplete`
  - `capture started sampleRateHz=16000`
  - `stream started`
- [ ] Backend logs show:
  - `session minted sessionId=...`
  - `proxy connected sessionId=...`
  - `setupComplete received from upstream`
- [ ] Speak for **10+ seconds** — model responds with audible speech
- [ ] First audio chunk log includes `latencyMs=` (target: under ~2s on good network)
- [ ] Tap stop → journal entry saved with `captureContextTag: live_voice_capture`
- [ ] Flutter log on save includes `diagnostics LiveVoiceDiagnosticsSnapshot(...)` with non-zero `pcmChunksSent` and `audioChunksReceived`

## Authentication

- [ ] Session mint succeeds with capture attest token (no Gemini key in app logs or network)
- [ ] WebSocket connects with `sessionToken` query param only (token redacted in logs)
- [ ] Second WebSocket upgrade with same token fails (single-use consumption)

## Session lifecycle

- [ ] State progression: connecting → setupComplete → streaming
- [ ] Stop sends `audioStreamEnd` and closes socket cleanly
- [ ] Dispose/navigate away during recording cancels without saving

## Reconnect and error recovery

- [ ] Kill backend mid-recording → app shows “Live voice connection lost…” after one reconnect attempt
- [ ] Flutter logs: `session fault` then `reconnect started` (if network briefly drops and recovers, `reconnect succeeded`)
- [ ] Empty transcript stop returns to ready with helpful message (speak longer)
- [ ] Missing `GEMINI_API_KEY` on server → connect fails with error UI, no crash

## Cancellation

- [ ] Navigate away during live recording → session cancelled, no journal entry
- [ ] No API keys or session tokens in debug output (only `[redacted]`)

## Playback latency (manual)

- [ ] Model speech starts within ~1–2 s of finishing a short question
- [ ] No long gaps between consecutive spoken chunks during one reply
- [ ] `playbackQueueDepth` in diagnostics stays low (0–2) during steady playback

## Security / logging

- [ ] Grep device logs for `GEMINI`, `apiKey`, `AIza` — **no matches**
- [ ] Proxy URLs in logs use redacted `sessionToken`
- [ ] Backend logs never print raw session tokens or API keys

## Sign-off

| Field | Value |
|-------|-------|
| Device | |
| OS | |
| Backend URL | |
| Date | |
| Result | pass / fail |
| Notes | |
