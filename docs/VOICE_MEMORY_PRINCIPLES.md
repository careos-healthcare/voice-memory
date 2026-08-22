# Voice Memory Principles

These are the product invariants the codebase enforces. Each one is checked by a
gate, so changing a principle here means changing the check that guards it.

1. **Quiet copy.** Never expose raw analytical mechanics or confidence
   percentages in primary UI. Enforced by the `quiet-copy` banned-phrase scan in
   `scripts/validate-product-restraint.mjs`.
2. **Fast capture.** Recording is reachable with minimal friction; nothing is
   allowed to sit between the user and the microphone.
3. **Silence over filler.** When there is nothing worth surfacing, the product
   says nothing rather than generating filler. Enforced by the `archive-silence`
   check and `packages/shared/lib/archive/archive-silence.ts`, which is
   responsible for choosing silence over a manufactured prompt.
4. **Continuity over novelty.** Resurfacing prefers threads the user is already
   carrying over novel-but-unrelated material. Implemented in
   `packages/shared/lib/conversation/conversation-continuity.ts` and
   `continuation-loops.ts`.
5. **Archive permanence over engagement.** The archive is a durable record, not
   an engagement surface. Reflection data is never deleted, reordered, or
   gamified to drive return visits. See
   `packages/shared/lib/debug/archive-permanence-review.ts` and
   `packages/shared/lib/account/account-data-portability.ts`.
6. **No productivity framing.** The product is not a habit tracker, a streak, or
   a self-optimization tool, and copy must not frame it as one. Enforced by the
   banned-phrase scan and `packages/shared/lib/product/pro-framing.ts`.
7. **No emotional manipulation.** Nothing may use the user's own vulnerability
   to drive retention — no guilt, no manufactured urgency, no leveraging a low
   moment into engagement. Enforced by the `integrity` check and
   `packages/shared/lib/integrity/emotional-integrity.ts`.
