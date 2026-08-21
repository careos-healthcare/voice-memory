# Live voice integration (Gemini Live via backend proxy)

ArchiveMe does **not** embed a Gemini API key in Flutter. Live voice uses the layered stack under `lib/features/live_audio/` and the backend WebSocket proxy.

## Backend

1. Set in repo root `.env.local`:

```bash
GEMINI_API_KEY=your-key
AUTH_SECRET=your-secret-min-32-chars
```

2. Start the custom Node server (required for WebSocket upgrade):

```bash
npm run dev
```

Plain `npm run dev:next` does **not** attach `/api/live-audio/ws`.

3. Verify:

```bash
npm run validate:live-audio-protocol
npm run validate:live-audio-session
npm run validate:live-audio-ws
```

## Mobile

1. Point the app at your machine:

```bash
cd apps/mobile
flutter run \
  --dart-define=ENABLE_LIVE_VOICE_CAPTURE=true \
  --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000
```

Android emulator: use `http://10.0.2.2:3000`.

Physical device: use your LAN IP, e.g. `http://192.168.1.10:3000`.

2. Open Record and tap **Live conversation**. With the flag enabled:

- Record → `/live-voice` full-screen session
- `RecordLivePcm16CaptureSource` → `record` plugin @ 16 kHz PCM16 mono → coordinator → proxy
- `PlaybackService` → 24 kHz model audio via `audioplayers` (low-latency WAV chunks)
- `stopAndSave()` → analyze + journal entry (`captureContextTag: live_voice_capture`)

3. Run tests:

```bash
flutter test test/features/live_audio/
```

4. Physical device E2E: follow `docs/LIVE_VOICE_E2E_CHECKLIST.md`.

Dedicated UI: Record opens `/live-voice` (full-screen session with transcript preview, connection pill, Cancel / Stop & save). When the flag is on, the Record CTA reads **Live conversation**. Model replies use a green speaking waveform tied to playback queue depth, with a light haptic when a reply starts.

## Diagnostics

All live voice logs use the `ARCHIVEME_LIVE:` prefix. Sensitive values are redacted:

- `sessionToken` → `[redacted]` in proxy URL logs
- No Gemini API key on device

Key lifecycle logs: `session minted`, `connect started`, `setupComplete`, `stream started`, `pcm chunk sent`, `audio chunk received`, `reconnect started/succeeded`, `session fault`, `diagnostics`.

On successful save, Record screen logs `live voice diagnostics LiveVoiceDiagnosticsSnapshot(...)`.

## Architecture (do not use client-side GeminiLiveAudioSession)

| Snippet anti-pattern | ArchiveMe replacement |
|---------------------|------------------------|
| Client API key | Backend proxy + session token |
| Client setup frame | Server `GeminiLiveProxy` setup |
| `mediaChunks` | `realtimeInput.audio` @ 16 kHz |
| Monolithic ChangeNotifier | Coordinator + capture + playback + journal service |

## Audio hardware integration (do not copy snippet wiring)

The pasted `GeminiLiveAudioSession` + client API key pattern is **not** used. ArchiveMe already maps the same hardware concerns:

| Snippet concept | ArchiveMe implementation |
|-----------------|-------------------------|
| `record` + `startStream` @ 16 kHz PCM16 | `RecordLivePcm16CaptureSource` (`lib/features/live_audio/infrastructure/record_live_pcm16_capture_source.dart`) |
| `streamUserAudioChunk` → WebSocket | `LiveAudioSessionCoordinator.streamPcm16kChunk` → `realtimeInput.audio` via backend proxy |
| Raw PCM playback plugin | `PlaybackService` (`lib/audio/playback_service.dart`) — wraps 24 kHz PCM in WAV, `PlayerMode.lowLatency` |
| Client `connect()` + setup frame | `POST /api/live-audio/session` + server `GeminiLiveProxy` setup |
| Network drop / reconnect | `LiveVoiceCaptureService` → one automatic `reconnectSession()` (re-mint + WS); then user-visible fault |
| Barge-in (user speaks over model) | Server sends `serverContent.interrupted` → `LiveInterruptedEvent` → `PlaybackService.flushLivePcm()` clears playback queue |

Mic bytes never touch a client-side Gemini URL. Live voice configures native audio focus via `LiveAudioFocusGateway` (`audio_session` package, `voiceChat` / `voiceCommunication`) before capture starts. Classic one-shot capture still uses `record` / `IosAudioSessionConfigurator`.

### Native audio focus / interruptions

`LiveAudioFocusGateway` listens to `AudioSession.interruptionEventStream`:

- **Interruption begin** (incoming call, transient focus loss) → `pauseLiveCapture()` stops the mic and flushes playback **without** closing the proxy WebSocket or sending `audioStreamEnd`.
- **Interruption end** (when OS signals resume) → `LiveAudioFocusGateway.resumeCaptureIfPossible()` re-requests `setActive(true)` then resumes mic via `resumeLiveCaptureIfActive()`.

Logs: `ARCHIVEME_LIVE: native audio focus lost; live capture paused` / `native audio focus restored; live capture resumed` / `native audio focus re-requested before capture resume`.

### App lifecycle (screen)

`LiveVoiceSessionScreen` mixes in `WidgetsBindingObserver`:

- **`inactive` / `paused` / `hidden`** → `pauseLiveCapture()` while connecting or active (protects battery/privacy; keeps WebSocket open).
- **`resumed`** → `LiveAudioFocusGateway.resumeCaptureIfPossible()` (foreground gate + focus re-request + streamable session check).
- **`detached`** → terminates live session and releases audio focus.
- **`dispose`** → `terminateActiveSession()` tears down mic + proxy before navigating away.

### Error state machine

Failures are classified into [`LiveVoiceErrorState`](lib/features/live_audio/domain/models/live_voice_error_state.dart):

| State | Typical cause | User message theme |
|-------|---------------|-------------------|
| `networkTimeout` | WebSocket drop, setup timeout, reconnect exhausted | Check network, Try again |
| `tokenExpired` | Proxy/auth rejection, expired session token | Start a new session |
| `hardwareFailure` | Mic permission / native capture failure | Check microphone |
| `unknown` | Unclassified fault | Generic retry |

After auto-reconnect budget (`maxReconnectAttempts`, default 1) is exhausted, `handleSessionFailure()` pauses mic capture but keeps the session active for **`retrySessionRecovery()`** (manual Try again on the error screen).

### Barge-in

Gemini Live is full duplex. When the user talks over the model, upstream emits `interrupted: true`. The client flushes pending playback immediately (`ARCHIVEME_LIVE: barge-in playback flushed`). Mic streaming continues without a separate client “clear queue” frame — the server owns turn interruption.

Local amplitude VAD is **not** implemented yet; rely on server `interrupted` for v1.

### Network stability

- Session mint returns `ws://` / `wss://` proxy URL (never HTTP scheme on device).
- Single-use session tokens; reconnect re-mints via `connect(isReconnect: true)` (skips usage-guard cooldown).
- Mid-session socket loss → one reconnect attempt → fault UI if reconnect fails.
