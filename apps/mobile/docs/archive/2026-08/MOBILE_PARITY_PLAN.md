# ArchiveMe Mobile Parity Plan

Mobile (`apps/mobile`) is the **primary distribution surface**. Web internal dashboards and founder tooling are **out of scope** for v1.

| Web feature | Mobile status | v1 required | Deferred |
|-------------|---------------|-------------|----------|
| Onboarding | Implemented | Yes | — |
| Recording + mic permission | Implemented | Yes | — |
| Capture attest | Implemented | Yes | — |
| Transcription | Implemented | Yes | — |
| Analyze / reflection | Implemented | Yes | — |
| Journal list | Implemented | Yes | — |
| Entry detail | Implemented | Yes | — |
| Memory / archive view | Implemented | Yes | — |
| Archive value progress | Implemented | Yes | — |
| Blind spots (5+ unlock) | Local simplified review | Yes | Full web ranking engine |
| Discover / theory feed | Local simplified diff | Yes | Full pattern engine |
| Updates (theory notifications) | In-app list, local | Yes | Push notifications |
| Value-moment paywall | Implemented | Yes | — |
| Pricing / Stripe checkout | Browser / custom tab | Yes | Native IAP |
| Account email login | Implemented | Yes | — |
| Journal sync (signed in) | Implemented | Yes | Encrypted blob sync |
| Export archive | Implemented | Yes | — |
| Delete account | Implemented | Yes | — |
| Settings + privacy/terms | Implemented | Yes | — |
| Search | Route exists | No | v1.1 |
| Internal dashboards | — | No | Never on mobile |
| Founder test dashboard | — | No | Never on mobile |
| Full theory discovery analytics | — | No | Web only |
| Debug tooling | — | No | Web only |

## v1 user journey

**Record → archive gets smarter → first blind spot → discover changes → paywall after value.**

## API base URL

Set at build time (no localhost in release):

```bash
--dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```
