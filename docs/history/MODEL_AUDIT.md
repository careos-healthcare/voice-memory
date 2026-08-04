> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# ArchiveMe — AI Model Audit

**Date:** 2026-05-25  
**Scope:** Full repository (`voice-memory`) — web (Next.js) + mobile (Flutter)  
**Method:** Static code audit of all OpenAI (and model-like) call sites. **No code changes.**

---

## Summary

ArchiveMe uses **three OpenAI model IDs** in production API routes, all via `getOpenAIClient()` (`lib/openai.ts` → OpenAI Node SDK). **No Anthropic, Gemini, Claude, or embedding APIs** appear in the codebase.

**Archive beliefs, contradictions, blind spots, Deep Dive, and Archive Analyst do not call LLMs.** They are **heuristic / rules engines** over journal entries and reflection metadata. The only LLM that **indirectly feeds** archive beliefs is **`gpt-4o-mini`** on **`POST /api/analyze`**, which structures each reflection at capture time.

| Model ID | Route / use | Modality |
|----------|-------------|----------|
| `whisper-1` | `POST /api/transcribe` | Speech-to-text |
| `gpt-4o-mini` | `POST /api/analyze`, `POST /api/weekly-reflection` | Chat (JSON) |
| `dall-e-3` | `POST /api/atmosphere` (opt-in) | Image |

There is **no embedding model** and **no vector retrieval** in production code.

---

## 1. Belief generation

Belief **statements** are not LLM-generated at read time. They are **selected or composed** from stored reflections and pattern/theory heuristics.

### Web

| Field | Value |
|-------|--------|
| **File** | `lib/archive/archive-belief.ts` |
| **Function** | `buildArchiveBeliefView()` |
| **Provider** | None (local) |
| **Model** | None |
| **Upstream LLM** | `gpt-4o-mini` via `app/api/analyze/route.ts` → populates `concreteObservation`, themes, etc. |
| **Pipeline** | `buildTheoryTrackerReport()` → `lib/theories/theory-generation.ts` → `lib/patterns/pattern-engine.ts` → `pickLeadTheory()` |
| **Temperature** | — |
| **Max tokens** | — |
| **Reasoning** | — |
| **Structured output** | — |

Supporting belief logic:

| File | Function | Model |
|------|----------|-------|
| `lib/theories/theory-generation.ts` | `buildTheoryTrackerReport()` | None |
| `lib/patterns/pattern-engine.ts` | `buildPatternEngineReport()` | None |

### Mobile

| Field | Value |
|-------|--------|
| **File** | `apps/voicememory_mobile/lib/features/discover/belief_engine.dart` |
| **Function** | `DiscoverBeliefEngine.build()` |
| **Provider** | None (on-device) |
| **Model** | None |
| **Upstream LLM** | Same `POST /api/analyze` when capture syncs ( `ApiClient.postAnalyze` ) |
| **Selection rule** | `archiveBeliefFromReflections()` — latest eligible `concreteObservation` ≥16 chars (`lib/features/archive_evidence/archive_evidence.dart`) |
| **Temperature / tokens / reasoning / structured** | — |

Archive V1 primary belief:

| File | Function | Model |
|------|----------|-------|
| `apps/voicememory_mobile/lib/features/archive_v1/archive_v1_builder.dart` | `ArchiveV1Builder.build()` | None (wraps `DiscoverBeliefEngine`) |

**Placeholder (non-model) fallback copy:** when evidence is thin, `DiscoverBeliefEngine` may return *"Your archive is still gathering evidence from your recordings."* — not an LLM.

---

## 2. Contradiction generation

### Web

| Field | Value |
|-------|--------|
| **File** | `lib/patterns/contradictions.ts` |
| **Functions** | `detectAllContradictions()`, `detectContradictionsForEntry()`, etc. |
| **Provider** | None |
| **Model** | None |
| **Method** | Regex, polarity flags, theme overlap, temporal pairing |
| **Temperature / tokens / reasoning / structured** | — |

Legacy shim: `lib/pattern-detection/contradiction-engine.ts` → re-exports web patterns.

Archive-facing: contradictions surface via `buildPatternEngineReport()` and `lib/archive/contradiction-history.ts` (still no LLM).

### Mobile

| File | Function | Model |
|------|----------|-------|
| `apps/voicememory_mobile/lib/features/discover/contradiction_engine.dart` | `DiscoverContradictionEngine.build()` | None |
| `apps/voicememory_mobile/lib/features/contradiction_detection/contradiction_detection_service.dart` | `detect()` | None |
| `apps/voicememory_mobile/lib/features/archive_v1/archive_theme_gap_engine.dart` | `build()` | None (theme frequency gaps) |

Uses `tensionOrContradiction` from reflections when present — field **may** be filled by analyze LLM, but **pair detection** is heuristic.

---

## 3. Blind spot generation

### Web

| Field | Value |
|-------|--------|
| **File** | `lib/blind-spots/blind-spot-review.ts` |
| **Function** | `buildBlindSpotReview()` (and related exports) |
| **Provider** | None |
| **Model** | None |
| **Pipeline** | `buildPatternEngineReport()` → ranking (`blind-spot-ranking.ts`) → templated headlines |
| **Temperature / tokens / reasoning / structured** | — |

### Mobile

| File | Function | Model |
|------|----------|-------|
| `apps/voicememory_mobile/lib/features/blind_spots/blind_spot_local.dart` | `BlindSpotLocalEngine.buildReview()` | None |
| `apps/voicememory_mobile/lib/features/discover/blind_spot_engine.dart` | `DiscoverBlindSpotEngine.build()` | None (local review + keyword heuristics for “help vs plans”) |

Comment in mobile: *"Simplified on-device pattern review — not the full web engine."*

---

## 4. Deep Dive

**Mobile only** (no web route or API).

| Field | Value |
|-------|--------|
| **File** | `apps/voicememory_mobile/lib/features/archive_deep_dive/archive_deep_dive_engine.dart` |
| **Function** | `ArchiveDeepDiveEngine.build()` |
| **Provider** | None |
| **Model** | None |
| **Composes** | `ArchiveV1View`, `BeliefTimelineEngine`, `CrossReferenceEngine`, `ArchiveDeepDiveInquiryEngine` |
| **Inquiry** | `archive_deep_dive_inquiry_engine.dart` — *"template only, no AI"* |
| **Temperature / tokens / reasoning / structured** | — |

Self-inquiry “saved as reflections” uses `ArchiveDeepDiveReflectionService` (local storage) — no model.

---

## 5. Archive Analyst

**Mobile only.**

| Field | Value |
|-------|--------|
| **File** | `apps/voicememory_mobile/lib/features/archive_analyst/archive_analyst_engine.dart` |
| **Function** | `ArchiveAnalystEngine.build()` |
| **Provider** | None |
| **Model** | None |
| **Plan** | `ARCHIVE_ANALYST_PLAN.md` — *"Non-goals: New LLM / AI infrastructure"* |
| **Confidence** | `archive_analyst_confidence_engine.dart` — *"no AI"* |
| **Catalog** | `archive_analyst_belief_catalog.dart` — reuses belief/evolution/identity engines |
| **Temperature / tokens / reasoning / structured** | — |

---

## 6. Search / retrieval

No semantic embedding retrieval. Search is **keyword / substring** scoring.

### Web

| Field | Value |
|-------|--------|
| **File** | `lib/semantic-life-search.ts` |
| **Function** | `semanticLifeSearch()` (and helpers) |
| **Provider** | None |
| **Model** | None (name is legacy; implementation is term matching, stopwords, field weights) |
| **Also** | `lib/journal-search.ts` → wrapper |
| **Archive evidence** | `lib/archive/evidence-search.ts` → `searchArchiveEvidence()` — substring match on beliefs/quotes |

### Mobile

| Field | Value |
|-------|--------|
| **File** | `apps/voicememory_mobile/lib/features/search/voice_memory_search.dart` |
| **Function** | `searchArchiveMe()` |
| **Provider** | None |
| **Model** | None — scans transcripts, beliefs, discover feed strings |

---

## 7. Embedding model

| Status | Detail |
|--------|--------|
| **Not implemented** | No `embeddings.create`, no Pinecone/pgvector/Supabase vector usage in app code |
| **Provider** | — |
| **Model** | — |

---

## 8. Fallback models (and non-model fallbacks)

### A. Atmosphere image API — explicit API fallback (no alternate LLM)

| Field | Value |
|-------|--------|
| **File** | `app/api/atmosphere/route.ts` |
| **Function** | `POST()` |
| **Primary model** | `dall-e-3` when `VOICEMEMORY_ENABLE_ATMOSPHERE_API=true` and `OPENAI_API_KEY` set |
| **Fallback** | JSON `{ source: "fallback", reason: ... }` — **no model** (disabled, error, empty response) |
| **Temperature / max tokens** | Not set on `images.generate` |
| **Structured output** | — |

### B. Capture / reflection — offline placeholder (no LLM)

| File | Function | Behavior |
|------|----------|----------|
| `apps/voicememory_mobile/lib/services/capture_pipeline_service.dart` | `_saveOfflineTextDraft()`, `_saveOfflineDraft()` | Saves entry with static `Reflection` copy (*"Cloud analysis pending"*) — **no model** |
| `lib/pending-reflection.ts` | `createPendingReflection()`, `createListeningModeEntry()` | Empty/minimal reflection until analyze runs |

When analyze **fails**, mobile does not call a secondary LLM; it keeps or saves non-analyzed state.

### C. OpenAI route failure — safe errors (no fallback model)

| File | Function |
|------|----------|
| `lib/server/openai-budget-guard.ts` | `safeOpenAiRouteError()` — production-safe codes, no model swap |
| `lib/server/openai-budget-core.ts` | Kill switch / budget — blocks routes, no cheaper model fallback |

### D. Belief card copy fallback

| File | Behavior |
|------|----------|
| `apps/voicememory_mobile/lib/features/discover/belief_engine.dart` | Static gathering-evidence statement when belief text empty |

---

## Other OpenAI call sites (not Archive Analyst sections, but in product)

### Per-reflection analysis (feeds entire archive)

| Field | Value |
|-------|--------|
| **File** | `app/api/analyze/route.ts` |
| **Function** | `POST()` |
| **Provider** | OpenAI |
| **Model** | `gpt-4o-mini` |
| **Temperature** | `0.35` |
| **Max tokens** | **Not set** (API default) |
| **Reasoning** | None (standard chat completions) |
| **Structured output** | `response_format: { type: "json_object" }` |
| **Callers** | `components/Recorder.tsx`, `lib/pending-reflection.ts`, `apps/voicememory_mobile/lib/api/api_client.dart` → `postAnalyze()` |

### Weekly pattern summary

| Field | Value |
|-------|--------|
| **File** | `app/api/weekly-reflection/route.ts` |
| **Function** | `POST()` |
| **Provider** | OpenAI |
| **Model** | `gpt-4o-mini` |
| **Temperature** | `0.75` |
| **Max tokens** | **Not set** |
| **Reasoning** | None |
| **Structured output** | `response_format: { type: "json_object" }` |
| **Caller** | `components/weekly/WeeklyAiReflection.tsx` |

### Transcription

| Field | Value |
|-------|--------|
| **File** | `app/api/transcribe/route.ts` |
| **Function** | `POST()` |
| **Provider** | OpenAI |
| **Model** | `whisper-1` |
| **Temperature / max tokens / reasoning / structured** | N/A (audio API) |

### Cost estimation (not runtime)

| File | Notes |
|------|-------|
| `lib/server/openai-cost-estimator.ts` | Assumes `gpt-4o-mini` pricing for analyze + weekly; `whisper-1`, `dall-e-3` |

---

## Heuristic-only archive-related modules (no model)

| Area | Primary files |
|------|----------------|
| Belief evolution | `belief_evolution_service.dart` |
| Identity traits | `identity_engine.dart` |
| Theme tracking | `theme_tracker_service.dart` |
| Timeline / explanations | `belief_timeline_engine.dart`, `archive_explanation_engine.dart` |
| Archive prompts | `archive_prompt_engine.dart` (mobile), `lib/archive/archive-prompt-engine.ts` (web) |
| Instant reflection UI line | `instant_reflection_response_engine.dart` |
| Resurfacing / memory notes | `lib/resurfacing/*`, `lib/patterns/memory-notes.ts` |
| Emotional A+ eval | `lib/emotional-quality/run-aplus-eval.ts` — tests heuristics, no LLM |

---

## Answers

### 1. Which model is used most frequently?

**`whisper-1`** and **`gpt-4o-mini`** on every successful **voice** capture path (transcribe then analyze). For **text-only** capture, only **`gpt-4o-mini`** (analyze). Among chat models, **`gpt-4o-mini`** dominates because archive surfaces do not call the API at read time.

### 2. Which model produces Archive beliefs?

**None at belief-read time.** Archive belief **text** comes from heuristics over stored data. The **inputs** are shaped by **`gpt-4o-mini`** at **`POST /api/analyze`** (`concreteObservation`, `recurringThemes`, `tensionOrContradiction`, etc.). Web beliefs additionally flow through **`buildTheoryTrackerReport()`** (pattern engine, no LLM).

### 3. Which model produces Archive Analyst conclusions?

**None.** `ArchiveAnalystEngine` is 100% on-device composition and scoring. Conclusions inherit wording from reflections (analyze LLM) and heuristic engines (V1, Deep Dive, catalog, confidence).

### 4. Is any archive logic heuristic-only?

**Yes — almost all archive read paths:**

- Archive V1, Deep Dive, Archive Analyst (mobile)
- Contradictions, blind spots, competing beliefs, debates, emerging/fading trends
- Web archive belief, theories, pattern insights, archive Q&A (`archive-question-engine.ts`)
- Search / evidence search

**LLM-touching exception:** reflection **creation** at capture (`/api/analyze`), which upstream affects all archive features.

### 5. What is the highest-capability model currently in use?

For **language reasoning:** **`gpt-4o-mini`** (only chat model in repo).  
For **images:** **`dall-e-3`** (optional).  
For **audio:** **`whisper-1`**.  
No `gpt-4o`, `o1`, `o3`, or Claude models are referenced.

### 6. What would be required to upgrade everything to the strongest available model?

There is **no single switch** — archive synthesis is mostly non-LLM. A full upgrade would mean:

1. **Change API route model IDs** in `app/api/analyze/route.ts` and `app/api/weekly-reflection/route.ts` (and optionally `app/api/atmosphere/route.ts` if moving to a newer image model).
2. **Update budget guard** — `lib/server/openai-cost-estimator.ts` pricing constants and daily USD caps in `openai-budget-core.ts` / env vars.
3. **Re-validate JSON contracts** — analyze uses `response_format: json_object` + `parseReflection()`; a stronger model may need prompt tuning, `max_tokens` explicit limits, or schema stricter than JSON mode.
4. **Reasoning models** (`o1` / `o3` / `gpt-5.*`): different API surface (may not support `temperature` / `response_format` the same way); routes would need redesign, not a drop-in rename.
5. **Latency & mobile capture** — `CapturePipelineService` blocks on analyze; stronger/larger models increase wait time and cost per recording.
6. **Regression testing** — reflection field quality, banned-phrase checks in analyze route, archive quality fixtures (`test/archive_quality_validation_test.dart`).
7. **Optional: actually use LLMs for archive** — Deep Dive / Analyst today are intentionally heuristic; upgrading “everything” to strongest models would be a **product/architecture change** (new prompts, routes, gating, privacy copy), not a model string change.
8. **Embeddings** — not present; semantic search upgrade would be **new infrastructure** (embedding model + index + query path), not a model swap.

---

## Environment variables (models)

From `.env.example` — no per-model overrides; model IDs are **hardcoded** in route files:

- `OPENAI_API_KEY` — required for transcribe + analyze
- `VOICEMEMORY_ENABLE_ATMOSPHERE_API` — gates `dall-e-3`
- Budget / kill-switch vars — limit spend, do not select model

---

## Audit limitations

- **Runtime config:** Production could override via forked deploys; this audit reflects **source in repo**.
- **Serverless secrets:** No access to live Vercel env beyond documented names.
- **Future / commented code:** Not exhaustively listing every markdown mention of “ChatGPT” in copy/comparison docs.

