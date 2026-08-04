> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# ASO & acquisition positioning

ArchiveMe is a **private voice journal** people use to **hear themselves again** — not a coach, therapist, or productivity tool.

## Core acquisition language

Lead with:

- **Private voice journal** — what it is in one breath
- **Hear yourself again** — emotional promise without abstraction
- **Your reflections stay on your device** — trust anchor
- **Old thoughts may return when they still fit** — revisit behavior, plain language
- **Return when something matters** — no streaks, no performance

Supporting phrases:

- Speak what you are actually thinking
- Revisit past reflections in your own voice
- Notice what keeps coming back
- Calmer than a feed, quieter than a diary app with scores

## Forbidden abstract wording

Do **not** use in store listings, screenshots, onboarding, or push copy:

| Avoid | Why |
| --- | --- |
| longitudinal | Clinical / research jargon |
| continuity intelligence | Sounds like enterprise software |
| archive graph | Engineer-facing |
| emotional AI | Implies replacement for human feeling |
| identity engine | Abstract, uncanny |
| memory system | Product infrastructure language |
| reflection engine | Feature jargon |
| cognitive / behavioral intelligence | Diagnostic framing |
| pattern engine / insight engine | Internal product vocabulary |
| AI coach / therapy bot | Wrong category & trust risk |

## High-intent journaling keywords

Use naturally (never stuffed):

**Primary:** voice journal, private journal, voice diary, audio journal, speak your thoughts, journal by voice

**Revisit / memory:** revisit old entries, hear yourself again, past reflections, voice memories, remember what you said

**Emotional (plain):** calm journaling, quiet reflection, personal thoughts, emotional journal (sparingly)

**Privacy:** private journal, on-device, encrypted backup, export journal

**Avoid over-indexing:** productivity journal, habit tracker, mood score, AI therapist, life coach

## Emotional entry points

Install moments we optimize for:

1. **Overwhelmed but not in crisis** — wants to talk without an audience
2. **Repeating the same thought** — wants to hear if they said this before
3. **Privacy-sensitive** — tried apps that felt public or performative
4. **Return after a hard week** — wants continuity, not a blank page
5. **Curious about their own tone** — wants to replay their voice from before

Copy should name the **felt situation**, not the feature.

## Screenshot copy strategy

- **Max 7 words** per screen headline
- **One idea per screen** — no feature lists on images
- Order: promise → how it works → privacy → revisit → continuity → trust
- Show **realistic UI crops**, not abstract gradients with jargon
- Four sets for testing: **emotional**, **privacy**, **revisit**, **continuity**
- Sub-lines (if used) stay under 12 words and explain *what you do*, not *how we built it*

## Onboarding positioning

First session should answer in order:

1. What is this? → Private voice journal
2. Where does it go? → Your device
3. What might happen later? → Older reflections may resurface gently
4. What is optional? → Backup, export, revisit, follow-up recording
5. What is it not? → Not therapy, not coaching, not productivity

Hooks must be **immediately understandable** without reading docs.

## Notification tone

If we nudge (sparingly):

- Gentle, optional, no guilt
- Reference *their* words when possible
- Never: streaks, scores, “you haven’t journaled”, performance language

Examples:

- “A past reflection might still fit today.”
- “You saved something to return to.”
- “Your voice from last month is still here.”

Never:

- “Keep your streak alive”
- “Weekly performance ready”
- “We analyzed your patterns”

## Review response tone

- Thank the person by name when possible
- Acknowledge the feeling they named
- Explain in plain language — one sentence on privacy if relevant
- No defensiveness, no clinical disclaimers in full unless safety-related
- Invite email for bugs; do not argue in public replies

Templates live in `lib/marketing/acquisition-copy.ts` → `REVIEW_RESPONSE_TEMPLATES`.

## Measurement (debug only)

- `/debug/acquisition-review` — clarity score, keyword coverage, banned phrase scan
- First-session comprehension events — revisit understood, old entry opened, audio replayed
- Founder export bundles positioning + risks for store iteration

