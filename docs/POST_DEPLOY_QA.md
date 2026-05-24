# Post-deploy QA — VoiceMemory

Run after each production deploy or before inviting testers. Check off each item; note browser and device.

**Production URL:** _____________________  
**Deploy date:** _____________________  
**Tester:** _____________________

---

## Core flows

### Account login

- [ ] Open `/account`
- [ ] Enter email → receive code (requires SMTP in production; skip if not wired)
- [ ] Verify code → session persists after refresh
- [ ] Sign out clears session

### Recording & entry

- [ ] Homepage recorder starts on tap/click
- [ ] Recording completes → transcript appears
- [ ] Analysis completes → entry page loads
- [ ] Transcript readable; reflection sections present
- [ ] Audio playback works

### Encrypted backup (sync)

- [ ] Sign in on production
- [ ] Trigger sync from account/settings if exposed
- [ ] Network tab: `/api/sync/push` sends only `encrypted.ciphertext` + `iv`
- [ ] `/api/sync/pull` requires session (401 when signed out)

### Restore rollback

- [ ] Export all from Settings
- [ ] Delete all local data
- [ ] Restore from export → entries return
- [ ] Pre-restore backup available if restore fails mid-way

### Photo attach

- [ ] Open entry → attach one photo
- [ ] Photo compresses and displays
- [ ] Photo survives page refresh
- [ ] Photo included in export metadata

### Atmosphere generation

- [ ] With API **disabled**: “Create quiet atmosphere” → local gradient saves
- [ ] No user-facing error on fallback
- [ ] With API **enabled** (optional): image generates and attaches

### Revisit flow

- [ ] Open existing entry from timeline/archive
- [ ] Revisit note may appear (or silence if intelligence active)
- [ ] Bookmark / copy moment if offered
- [ ] No guilt copy or blocked navigation

### Roundups

- [ ] Open `/roundups` or monthly/weekly roundup
- [ ] Period view loads without error
- [ ] “Save to return to” works
- [ ] “Continue this thought” hidden when silence intelligence suppresses prompts

### Territories

- [ ] Open `/territories`
- [ ] Preset territory pages load
- [ ] Entry page “This also belongs around…” link works when detected

### Silence intelligence

- [ ] Settings → Silence intelligence toggle on/off
- [ ] After ignored callbacks, fewer proactive notes
- [ ] Optional line: “Nothing needs to surface right now.” or “You can just leave this here.”
- [ ] Recording, export, delete never blocked

---

## Browser matrix

### Mobile Safari (iOS)

- [ ] Homepage loads
- [ ] Microphone permission on first record
- [ ] Record → complete → entry view
- [ ] Scroll and back navigation
- [ ] localStorage persists after backgrounding

### Android Chrome

- [ ] Same recording flow as iOS
- [ ] File attach for photo (if supported)
- [ ] No layout breakage on small viewport

### Desktop Chrome

- [ ] Full recording flow
- [ ] Settings export/import
- [ ] Timeline and archive navigation
- [ ] Debug routes redirect to `/` (unless debug token set)

### Desktop Safari

- [ ] Recording flow
- [ ] IndexedDB / localStorage (audio blobs)
- [ ] Export download

---

## Security & ops

- [ ] `/debug/*` not reachable without token in production
- [ ] No secrets in page source or network responses
- [ ] `AUTH_SECRET` set in Vercel (app does not crash on auth routes)
- [ ] OpenAI errors show generic message, not stack traces

---

## Issues log

| # | Area | Browser | Steps | Expected | Actual | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |
| 2 | | | | | | |

---

## Sign-off

- [ ] All **Core flows** passed or documented as known gaps
- [ ] At least one mobile browser verified
- [ ] Export/restore verified on production
- [ ] Ready for testers: **Yes / No**

Notes:

_______________________________________________
