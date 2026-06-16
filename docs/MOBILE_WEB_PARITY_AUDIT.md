# Mobile / Web Parity Audit — ArchiveMe

Generated: 2026-06-13T12:53:09.477Z

> Mobile is the primary distribution platform. Do not blindly port web features to mobile.

## A. Executive summary

**Is mobile missing anything launch-critical from web?**

No launch-blocking gaps found. Mobile already covers record, archive, search (Ask Archive + filters), export (JSON), action items, details, packs, collections, pins, memory controls, privacy, and RevenueCat paywall. Remaining gaps are format depth (markdown/print export) and web-style semantic search filters — both classified later.

**Is web carrying legacy/experimental surfaces that should not drive mobile?**

Web still carries desktop personalization (visual tone, ambient adaptation), PWA install prompt, marketing homepage with competitor comparison, session outcome overlay, and many demoted archive analysis routes. These should not expand mobile scope.

**Should distribution continue mobile-first?**

Yes — Flutter is the primary distribution platform. Web/PWA is support: landing, privacy, pricing/account, and internal founder tooling.

**Recommendation**

Keep mobile distribution priority. Do not blindly port web settings or experimental archive pages to Flutter. Use web for trust URLs, Stripe checkout, and internal QA. Revisit parity after 20–50 testers.

## B. Feature comparison table

| Feature | Web | Mobile | User value | Classification | Decision | Reason | Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Visual tone | yes | no | Personal aesthetic preference on long desktop sessions. | web_only | Do not port to mobile before launch. | Native app uses system theme and focused capture surfaces; tone prefs are desktop polish. | Keep in web Settings only; revisit post-launch if users ask. |
| Automatic time-of-day tone | yes | no | Subtle ambient UI shift by time of day on web. | later | Defer on mobile. | Nice ambient detail; no impact on record, trust, or paywall. | Leave web-only for now. |
| Ambient adaptation | yes | no | Warmth/contrast comfort adjustments on web. | later | Defer on mobile. | Accessibility-adjacent but not launch-blocking; mobile has native contrast settings. | Monitor accessibility feedback after launch. |
| PWA install prompt | yes | n/a | Add web app to home screen on Chromium browsers. | web_only | Keep web-only; never port to Flutter. | Native apps install via App Store / Play; prompt is PWA-specific. | Show only when beforeinstallprompt is available; hide otherwise (already gated). |
| “Did this help?” session feedback | yes | partial | Qualitative session outcome for retention learning. | later | Optional parity after aha/proof moments. | Useful for founder learning; not required for first save or Day 2. | Keep web overlay; mobile has aha feedback rows — unify metrics later. |
| Landing / marketing home | yes | n/a | Acquisition story, demo, proof wall on desktop. | web_only | Web acquisition surface only. | Mobile distribution is store listing + in-app first-run, not marketing homepage. | Keep web home lean on mobile web; do not expand Flutter scope. |
| Privacy page | yes | yes | Trust, store review, legal transparency. | needed_for_launch | Required on both platforms. | App Store / Play and user trust require reachable privacy policy. | Mobile in-app summary + link to deployed web policy. |
| Terms / safety pages | yes | partial | Legal and emotional-safety references. | needed_for_launch | Web canonical; mobile links out where needed. | Store compliance and trust; mobile opens external trust URLs. | Keep web pages current; mobile Terms via external link is sufficient. |
| Account / sign-in | yes | yes | Encrypted backup and cross-device restore. | needed_for_launch | Required where backup is offered. | Protect-archive and restore flows depend on auth. | Continue native auth QA; do not block launch on web Stripe account UI. |
| Pricing / paywall | yes | yes | Pro upgrade and restore. | needed_for_launch | Platform-specific billing on both. | Revenue path is launch-critical; Stripe (web) and RevenueCat (mobile) are intentional splits. | Keep separate billing stacks; align copy not checkout mechanics. |
| Record | yes | yes | Core voice capture loop. | needed_for_launch | Must work on mobile first. | Primary product action. | Prioritize mobile record QA over web personalization. |
| Save entry | yes | yes | Persist transcript, reflection, and audio locally. | needed_for_launch | Required on mobile. | First save and second save depend on reliable save path. | No web-only save enhancements before mobile launch. |
| Archive / journal home | yes | yes | Browse beliefs, patterns, and entries. | needed_for_launch | Mobile Patterns tab is primary archive home. | Return loop and archive value live here. | Keep /archive-belief parity; journal list remains dev-gated on mobile. |
| Search | yes | partial | Find past reflections and archive content. | needed_for_launch | Mobile must ship usable search, not web semantic parity. | Users need to find entries; mobile has Ask Archive + journal search engine. | Do not port web mood/theme filters pre-launch; validate Ask Archive + pins/collections. |
| Pins / pinned evidence | partial | yes | Keep important evidence visible. | needed_for_launch | Mobile leads; web partial is acceptable. | Mobile /pinned-evidence is consumer-ready. | No port required from web. |
| Collections | partial | yes | Group related entries. | needed_for_launch | Mobile-native feature is launch scope. | Organizational control supports retention. | Keep mobile collections; web can stay partial. |
| Export | yes | partial | Data portability and ownership. | needed_for_launch | Mobile JSON export is sufficient for launch. | Store review expects export; markdown/print are enhancements. | Ship mobile JSON export; add formats later if testers request. |
| Archive packs | no | yes | Scoped sub-archives with instructions. | needed_for_launch | Mobile-only launch feature. | Already shipped on Flutter; not a web parity requirement. | Do not port to web before mobile launch. |
| Action items | no | yes | Remember-this tasks linked to entries. | needed_for_launch | Mobile-only launch feature. | Core mobile workflow; trust copy references it. | Keep mobile-only. |
| Details / fact ledger | partial | yes | Saved facts separate from full entries. | needed_for_launch | Mobile /details is launch scope. | Users save durable facts; mobile screen is complete. | No web port required pre-launch. |
| Memory controls (scope / governance) | partial | yes | Control what connects to memory and surfacing. | needed_for_launch | Mobile is ahead; keep as-is. | Trust and control are launch-critical; mobile has explicit scope modes. | Do not simplify mobile to match thinner web settings. |
| Surfacing controls | partial | yes | Choose what resurfaces and when. | needed_for_launch | Required on mobile. | User agency over resurfacing is core trust. | Continue mobile memory widget QA. |
| Hypothetical / Not about me | partial | yes | Mark entries that should not define self-model. | needed_for_launch | Required on mobile entry editors. | Prevents wrong self-inference; tested on mobile. | No web port pressure. |
| Sensitive / Do not surface | partial | yes | Protect sensitive content from resurfacing. | needed_for_launch | Required on mobile. | Safety and trust at launch. | Keep mobile guards; web partial is fine. |
| Preserve original | partial | yes | Keep verbatim evidence intact. | needed_for_launch | Required on mobile. | Archive integrity feature. | No change needed. |
| Topic shift guard | partial | partial | Detect when a new topic should not inherit old thread context. | later | Defer full parity. | Helpful governance edge case; not blocking first-week loop. | Revisit after 20–50 testers. |
| Aha moment | partial | yes | First archive recognition beat. | later | Mobile implementation is sufficient for launch. | Mobile first_aha_moment_card exists; web discovery differs. | Tune copy from mobile feedback, not web parity. |
| Pro trust card / value clarity | yes | yes | Explain Pro without pressure before paywall. | needed_for_launch | Required on both; platform-specific triggers. | Conversion after value moment needs trust framing. | Align ArchiveMe copy; keep separate trigger engines. |
| Commercial metrics / launch QA | yes | partial | Founder evidence for store and revenue readiness. | web_only | Internal/founder tooling on web. | Not consumer product surface. | Use /internal/launch and mobile-readiness reports. |
| Internal dashboards | yes | no | Founder command center, activation/return/conversion readouts. | web_only | Never port to consumer mobile. | Gated /internal/* routes are not mobile parity requirements. | Keep noindex; do not add to Flutter nav. |
| Web-only archive analysis pages | yes | no | Theories, blind-spots, discover, archive-detail hub on desktop. | web_only | Do not port wholesale to mobile. | Simplicity mode demotes these on web; mobile uses Patterns + Ask Archive. | Hide from public primary nav; treat as experimental desktop depth. |
| Push / notification internal pages | yes | partial | Founder verification of FCM/APNs readiness. | web_only | Internal evidence only. | Consumer push lives in Flutter; internal pages are QA. | Use /internal/mobile-push-readiness; not a parity gap. |
| Competitor comparison (homepage) | yes | no | Desktop acquisition positioning. | remove_or_hide | Remove or hide from public primary product path. | Consumer-facing competitor framing adds brand risk and scope creep. | Demote HomepageChatGptComparison from default mobile web stack; do not port to Flutter. |
| Desktop personalization settings block | yes | no | Reflection goals, listening mode, full-detail quiet mode, photo prefs. | later | Selective mobile ports only if testers block. | Web settings breadth exceeds mobile launch scope. | Keep mobile settings focused on archive org, security, export, privacy. |
| Web archive permanence (/archive export hub) | yes | partial | JSON/Markdown/ZIP import-export and ownership panel. | later | Mobile JSON export covers launch minimum. | Full permanence hub is web-heavy; mobile export + delete account suffices initially. | Add markdown/zip on mobile only if store review or testers require. |
| Retention loop (Day 2 / reminders) | partial | yes | Return after first archive value. | needed_for_launch | Mobile-native retention is launch scope. | Distribution priority is mobile return loop. | Prioritize Flutter reminder + day-2 cards over web prompt parity. |

## C. Classification rules

- **needed_for_launch** (Needed for launch): Blocks mobile launch or directly affects first save, second save, Day 2, trust, paywall, privacy, or purchase.
- **later** (Later): Useful but not launch-blocking; revisit after early testers.
- **web_only** (Web only): Useful on desktop/PWA but not required in the native Flutter app.
- **remove_or_hide** (Remove or hide): Public web surface adds confusion, old brand risk, internal complexity, or should not drive mobile scope.

## D. Expected classifications (spot check)

- Visual tone → web_only
- Automatic time-of-day tone → later
- Ambient adaptation → later
- PWA install prompt → web_only
- Session feedback overlay → later
- Privacy / pricing / record / search / export / action items / details / memory controls → needed_for_launch
- Internal dashboards → web_only
- Competitor comparison → remove_or_hide

## E. Action plan

1. Keep mobile as the primary distribution platform.
2. Do not port web personalization settings (visual tone, ambient adaptation, auto tone) before launch.
3. Keep PWA install prompt gated on beforeinstallprompt only; hide when unavailable.
4. Keep web focused on landing, privacy, pricing/account, and /internal dashboards.
5. Continue native mobile QA on record, archive, paywall, privacy, export, and memory controls.
6. Revisit mobile/web parity after 20–50 testers — not before.

## F. PWA install prompt

InstallPrompt already renders only when `beforeinstallprompt` fires and eligibility gates pass. No copy change required for this audit.

## G. Inspected paths

### Web

- `app/settings/page.tsx`
- `components/settings/*`
- `components/retention/SessionOutcomePrompt.tsx`
- `components/mobile/InstallPrompt.tsx`
- `components/ActivationOnboarding.tsx`
- `components/OnboardingBanner.tsx`
- `components/Recorder.tsx`
- `components/SiteHeader.tsx`
- `app/page.tsx`
- `app/privacy/page.tsx`
- `app/pricing/*`
- `app/archive*`
- `app/internal/*`
- `lib/product/*`
- `lib/retention/*`
- `lib/distribution/*`
- `lib/mobile/*`

### Mobile

- `apps/voicememory_mobile/lib/screens/settings_screen.dart`
- `apps/voicememory_mobile/lib/screens/record_screen.dart`
- `apps/voicememory_mobile/lib/screens/journal_screen.dart`
- `apps/voicememory_mobile/lib/screens/privacy_screen.dart`
- `apps/voicememory_mobile/lib/screens/paywall_screen.dart`
- `apps/voicememory_mobile/lib/screens/action_items_screen.dart`
- `apps/voicememory_mobile/lib/screens/fact_ledger_screen.dart`
- `apps/voicememory_mobile/lib/screens/archive_packs_screen.dart`
- `apps/voicememory_mobile/lib/widgets/retention/*`
- `apps/voicememory_mobile/lib/widgets/aha/*`
- `apps/voicememory_mobile/lib/widgets/trust/*`
- `apps/voicememory_mobile/lib/widgets/memory/*`
- `apps/voicememory_mobile/test/* (settings, privacy, record, paywall, search, export, action items, details)`

## Internal note

Internal `/internal/*` routes are founder tooling — not mobile parity requirements.
