# ArchiveMe focused V1 reviewer instructions

The product category is: **Auditable personal change.**

The product promise is: “See what repeated. See what changed. Verify it in your
own words.”

In full: a private change ledger that shows exactly what repeated, what changed,
the words proving it, and lets you correct the record.

AI is used for transcription and for drafting each observation. That is a
processing detail, not the positioning: no observation reaches the reader without
the exact saved words and dates behind it.

Review the shipping Flutter client in this order:

1. Save one voice or typed moment.
2. Verify the only post-save hierarchy is Saved, editable transcript, zero or
   one cautious observation, inline exact evidence, correction controls, and
   one next action.
3. Edit the transcript so the cited quote no longer matches. The stale
   interpretation must disappear.
4. Save a related second moment. A comparison may appear only when the two
   distinct sources are topically aligned and meaningfully different.
5. Open Changes. Verify chronological status, full dates, Then/Now quotes,
   evidence count, uncertainty, correction state, and exact source navigation.
6. Submit Accurate, Wrong angle, Too generic, and Hide feedback. Wrong angle,
   Too generic, and Hide suppress the current framing without changing the
   original moment.
7. Verify the first observation and first valid comparison are free, existing
   outputs stay readable after expiry, and no original or evidence source is
   paywalled.

Reject the build if Record or Changes exposes a graph, analyst, blind-spot,
contradiction, streak, reminder, milestone, or multi-card insight journey.
Also reject generic, diagnostic, identity, zero-confidence, stale-offset,
same-source Then/Now, or deleted-source claims.

Reject the positioning if any primary headline leads with an AI journal, an AI
that remembers or knows you, personalised insights, ask-your-history-anything, a
life operating system, a memory assistant, a hidden truth, therapy, diagnosis, or
personality analysis. Those are encoded as forbidden primary headlines in
`config/product/archive_me_v1_contract.json` and enforced by
`apps/voicememory_mobile/test/product_positioning_copy_test.dart`.
