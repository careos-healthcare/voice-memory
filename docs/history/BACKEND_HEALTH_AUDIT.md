> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Backend health audit — Settings > Backend health shows "unreachable"

**Scope:** Read-only audit of the Flutter mobile app (`apps/voicememory_mobile`). No code was changed.

**Date:** 2026-05-25

---

## Executive summary

"Unreachable" is **not** returned by the server. It is a **client-side catch-all** label when `_refresh()` in Settings throws **any** exception. The most common causes are:

1. **Debug default base URL points at a local Next.js server that is not running** (`http://127.0.0.1:3000` or `http://10.0.2.2:3000`).
2. **A `.env` file sets `BACKEND_URL=http://127.0.0.1:3000`**, which applies on **physical devices** too (127.0.0.1 is the phone, not your Mac).
3. **HTTP cleartext to localhost on Android** (no `usesCleartextTraffic` / network security config in the manifest).
4. **Less common:** corrupt local journal JSON causes `journalStore.loadAll()` to throw **after** a successful health response, and Settings still shows "unreachable".

Production host `https://voice-memory-iota.vercel.app/api/health` responds **200** with JSON `{"status":"ok",...}` when probed from this environment.

---

## 1. Backend health widget

| Item | Location |
|------|----------|
| Settings UI | `apps/voicememory_mobile/lib/screens/settings_screen.dart` |
| Duplicate probe (home) | `apps/voicememory_mobile/lib/screens/home_screen.dart` (`API health: …`) |
| HTTP client | `apps/voicememory_mobile/lib/api/api_client.dart` → `health()` |
| API base URL | `apps/voicememory_mobile/lib/config/app_config.dart` + `backend_url_resolver.dart` |
| Startup resolution | `apps/voicememory_mobile/lib/main.dart` → `AppConfig.initApiResolution()` before `AppServices.initialize()` |

### Settings behavior

```28:40:apps/voicememory_mobile/lib/screens/settings_screen.dart
  Future<void> _refresh() async {
    try {
      final h = await AppServices.instance.api.health();
      final entries = await AppServices.instance.journalStore.loadAll();
      if (mounted) {
        setState(() {
          _health = h['status']?.toString() ?? 'ok';
          _entryCount = entries.length;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _health = 'unreachable');
    }
  }
```

- Initial label: `…`
- Success label: `h['status']` from JSON (e.g. `ok`, `degraded`) or `'ok'` if missing
- **Any** exception → `'unreachable'` (exception type and message are discarded)
- Debug-only row **API base URL** shows `AppConfig.apiBaseUrl` when `AppConfig.debugToolsEnabled` (`kDebugMode` or `VM_DEBUG_TOOLS`)

There is **no** "Backend health" row on the Next.js web Settings page (`app/settings/page.tsx`); this audit applies to the **native Flutter** app only.

---

## 2. Health check endpoint (server)

| Item | Value |
|------|--------|
| Route file | `app/api/health/route.ts` |
| Method | `GET` |
| Path | `/api/health` |
| Auth | None (public JSON) |
| Runtime | `nodejs` |

Response shape (always JSON, HTTP 200 in normal operation):

```json
{
  "status": "ok" | "degraded",
  "checks": { "databaseConfigured", "databaseReachable", "migrationsOk", ... }
}
```

`status` is `"degraded"` when DB/migrations/production checks fail; the route still returns **200** with a JSON body. The mobile client does **not** treat `"degraded"` as unreachable—it would display the string `degraded`.

---

## 3. Which endpoint is being called

**Full URL:** `{AppConfig.apiBaseUrl}/api/health`

**HTTP:** `GET` with headers `Accept: application/json`, `Content-Type: application/json`, and optional session `Cookie` if logged in.

```351:354:apps/voicememory_mobile/lib/api/api_client.dart
  Future<Map<String, dynamic>> health() async {
    final response = await _http.get(_uri('/api/health'), headers: _jsonHeaders);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
```

**Important:** `health()` does **not** check `response.statusCode`. Non-2xx responses only cause "unreachable" if `jsonDecode` throws or the body is not a JSON object map. A reachable server returning `"degraded"` still updates the tile to `degraded`, not `unreachable`.

---

## 4. API base URL source and environment variables

### Resolution order (`BackendUrlResolver.resolve()`)

1. **Dart compile-time defines** (highest priority):
   - `BACKEND_URL`
   - `VOICE_MEMORY_API_BASE_URL`
   - `API_BASE_URL` (legacy)
2. **`.env` files** (read at runtime from filesystem, not bundled in release):
   - `.env` (repo root, if cwd allows)
   - `apps/voicememory_mobile/.env`
   - Keys: same three as above
3. **`config/backend_url.txt`** (file or bundled asset) — repo file is **comment-only** (no active URL)

### Fallback when nothing above matches (`AppConfig.initApiResolution()`)

| Build / device | Resolved base URL |
|----------------|-------------------|
| **Release** (`kReleaseMode`) | `https://voice-memory-iota.vercel.app` |
| **Debug + Web** | `http://127.0.0.1:3000` |
| **Debug + emulator/simulator** (not physical) | Android: `http://10.0.2.2:3000` · iOS/macOS sim: `http://127.0.0.1:3000` |
| **Debug + physical device** | `https://voice-memory-iota.vercel.app` (production fallback) |

Constants in `app_config.dart`:

- `productionApiBaseUrl` / `stagingApiBaseUrl`: `https://voice-memory-iota.vercel.app`
- `defaultDevBaseUrl`: `http://127.0.0.1:3000`
- `defaultAndroidEmulatorBaseUrl`: `http://10.0.2.2:3000`

### Documented env / config files

| File | Content |
|------|---------|
| `apps/voicememory_mobile/.env.example` | `BACKEND_URL=http://127.0.0.1:3000` |
| `apps/voicememory_mobile/config/backend_url.txt` | Commented example only |

### Server-side env (health **logic**, not mobile URL)

Health checks use `DATABASE_URL`, `NODE_ENV`, Stripe/rate-limiter config, etc. (`app/api/health/route.ts`, `lib/server/production-readiness.ts`). These affect `"ok"` vs `"degraded"` on the server, not the mobile "unreachable" label.

---

## 5. Localhost references and emulator networking

| Reference | Purpose |
|-----------|---------|
| `127.0.0.1:3000` | iOS Simulator / default debug host (maps to dev machine loopback on sim) |
| `10.0.2.2:3000` | Android emulator alias for host machine's `localhost:3000` |
| `192.168.x.x:3000` | Documented for **physical** device → LAN IP of dev machine |
| `voice-memory-iota.vercel.app` | Production/staging/release fallback |

**Emulator assumption:** Host is running Next.js on port **3000** (`npm run dev` from repo root). If nothing listens on 3000, the health GET fails at the socket layer → `unreachable`.

**Physical device + `.env` trap:** Copying `.env.example` to `.env` sets `BACKEND_URL=http://127.0.0.1:3000`. That overrides production fallback and makes the phone call **itself** on port 3000 → connection failure → `unreachable`.

**iOS ATS:** `ios/Runner/Info.plist` has `NSAllowsArbitraryLoads` = **false** with no `NSExceptionDomains` for localhost. HTTP to `http://127.0.0.1:3000` may be blocked by App Transport Security depending on OS behavior; HTTPS production URL is unaffected.

**Android cleartext:** `android/app/src/main/AndroidManifest.xml` has **no** `android:usesCleartextTraffic="true"` and no network security config. HTTP to `10.0.2.2:3000` or `127.0.0.1` may be rejected on API 28+ as cleartext traffic.

---

## 6. Report (requested fields)

### 6.1 Which endpoint is being called

`GET {resolvedApiBaseUrl}/api/health`

### 6.2 Current URL being used (runtime-dependent)

Inspect at runtime:

- **Debug:** Settings → **API base URL** row (only when `debugToolsEnabled`).
- **Logs:** `AppConfig: API base from …` / `AppConfig: debug API base → …` from `initApiResolution()`.

**Typical values without custom defines:**

| How you run | Expected `apiBaseUrl` |
|-------------|------------------------|
| `flutter run` on Android emulator | `http://10.0.2.2:3000` |
| `flutter run` on iOS Simulator | `http://127.0.0.1:3000` |
| `flutter run` on physical phone (no `.env`/define) | `https://voice-memory-iota.vercel.app` |
| `flutter run` with `apps/voicememory_mobile/.env` from example | `http://127.0.0.1:3000` (all devices) |
| `flutter build * --release` (no define) | `https://voice-memory-iota.vercel.app` |
| Release with define | Value of `VOICE_MEMORY_API_BASE_URL` / `BACKEND_URL` |

### 6.3 Response code returned

| Target | Observed in audit environment |
|--------|--------------------------------|
| `https://voice-memory-iota.vercel.app/api/health` | **200** — body `{"status":"ok",...}` |
| `http://127.0.0.1:3000/api/health` | **No HTTP response** — connection refused (no dev server on :3000) |

When the app shows `unreachable`, you often **never get an HTTP status** because the failure is usually **before** a completed response (connection error, ATS, cleartext policy).

If the server responds but the body is not valid JSON, failure is **after** the response (parse phase).

### 6.4 Failure phase (before / during / after network)

| Phase | Symptoms in this codebase | Maps to "unreachable"? |
|-------|---------------------------|-------------------------|
| **Before network** | `BackendNotConfiguredException` when `!AppConfig.isBackendConfigured` or empty base (`_uri` returns null) | Yes |
| **During network** | `SocketException`, `ClientException`, timeout, TLS/ATS failure, Android cleartext block, connection refused | Yes (most common) |
| **After response** | `jsonDecode` / cast failure on non-JSON body; **or** `journalStore.loadAll()` throws on corrupt journal file | Yes |
| **Not "unreachable"** | HTTP 200 + valid JSON with `"status":"degraded"` | Shows **`degraded`** on tile |

The Settings widget **does not distinguish** health failure vs local journal failure.

### 6.5 Exact fix required

Apply the row that matches how you run the app:

| Scenario | Exact fix |
|----------|-----------|
| **Emulator/simulator, local backend** | From repo root: `npm run dev` (port 3000). Confirm health in browser: `http://127.0.0.1:3000/api/health`. Reopen Settings. |
| **Emulator, still failing (Android HTTP)** | Point app at **HTTPS** production instead of cleartext localhost: `flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app` **or** add Android cleartext allowance for debug (code change — not done in this audit). |
| **Physical device, local backend** | Do **not** use `127.0.0.1`. Remove or fix `apps/voicememory_mobile/.env` (`BACKEND_URL` must be `http://<your-mac-lan-ip>:3000`). Run: `flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://<LAN-IP>:3000`. Ensure Mac firewall allows port 3000. |
| **Physical device, production only** | Delete `.env` override; use release/debug production fallback, or explicitly: `--dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app`. |
| **Release / TestFlight build** | Build with `--dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app` (see `docs/MOBILE_BUILD_COMMANDS.md`). Verify tile shows `ok` or `degraded`, not `unreachable`. |
| **Production URL but still unreachable** | Check device network/VPN; confirm Settings debug row shows production host; rule out corrupt journal (see below). |
| **Health works but tile still unreachable** | Corrupt `journal.json` on device: `loadAll()` throws after successful health. Fix/rename local journal file or reset app data; **code improvement** (separate try blocks) would prevent mislabeling — out of scope for this audit. |

**Recommended default for QA without local server:**

```bash
cd apps/voicememory_mobile
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

---

## 7. Verification checklist

1. Note build mode (debug vs release) and device type (emulator / physical).
2. Read **API base URL** in Settings (debug) or startup `debugPrint` lines.
3. Curl the same base: `curl -sS -w "\n%{http_code}\n" "${BASE}/api/health"`.
4. If curl works but app shows `unreachable`, suspect **journal load** in the same `try` or device-specific HTTP policy.
5. If curl fails, start backend or switch base URL per table above.

---

## 8. Related files (quick index)

| Role | Path |
|------|------|
| Settings widget | `apps/voicememory_mobile/lib/screens/settings_screen.dart` |
| API health call | `apps/voicememory_mobile/lib/api/api_client.dart` |
| URL config | `apps/voicememory_mobile/lib/config/app_config.dart` |
| URL resolver | `apps/voicememory_mobile/lib/config/backend_url_resolver.dart` |
| Server route | `app/api/health/route.ts` |
| E2E health tests | `e2e/runtime-proof.spec.ts`, `e2e/prod-hardening.spec.ts` |
| Build docs | `apps/voicememory_mobile/docs/MOBILE_BUILD_COMMANDS.md`, `VALIDATION.md` |

---

## 9. Audit limitations

- **No on-device run** was performed in this audit; URL and status for your machine depend on how `flutter run` / `.env` / defines were set.
- **No code changes** were made; fixes above are operational (run commands, env files) except where platform policy (ATS/cleartext) or Settings error handling would need code changes.

