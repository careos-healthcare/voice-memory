# Flutter mobile app (separate from web)

The native Flutter client lives at **`apps/voicememory_mobile/`**. It does not replace the Next.js app.

## MVP core loop (implemented)

Record → attest → transcribe → analyze → local journal → export JSON.

See:

- `apps/voicememory_mobile/README.md` — run commands
- `apps/voicememory_mobile/VALIDATION.md` — analyze / test / APK
- Desktop: `spp20/native_core_loop_report.md`, `spp20/native_mvp_gap_report.md`

Backend routes are unchanged; Flutter calls `/api/capture/attest`, `/api/transcribe`, `/api/analyze` with `x-vm-capture-token`.
