# Human labels — CURRENTLY EMPTY

**There are no human labels yet. This directory contains no data.**

Nothing in `../fixtures/` is human-validated. Fixture expectations are
author-written synthetic intent: one engineer's judgement about what a careful
reader would say, written at the same time as the test input. They are useful
for catching regressions and for finding engine defects. They are **not**
ground truth, and no product claim about conclusion quality may cite them.

Until a file appears in this directory, every number produced by the harness is
a synthetic number.

## What belongs here

Only records where a human read the two moments and judged the conclusion
**without** seeing the expected answer. One file per labelling session:
`YYYY-MM-DD_<labeller-id>.json`.

## Format

Same record shape as `../schema.json`, with two differences:

- `humanLabelStatus` must be `humanLabelled`, or `disputed` when two labellers
  disagreed and the disagreement was not resolved.
- Every record carries the labelling metadata below.

```json
{
  "labellingSession": {
    "labelledOn": "2026-09-01",
    "labellerId": "labeller_02",
    "sawExpectedAnswer": false,
    "secondLabellerId": "labeller_05",
    "agreement": "agreed"
  },
  "cases": [
    {
      "caseId": "work_001_action_shift_pause",
      "...": "all fields from schema.json"
    }
  ]
}
```

`agreement` is one of `agreed`, `resolved`, `disputed`.

## Rules

1. **Synthetic transcripts only.** Real user journal content must never be
   copied into this repository, labelled or otherwise. Label synthetic text.
2. **Blind labelling.** A labeller who has seen the expected answer produces a
   confirmation, not a label. Set `sawExpectedAnswer` honestly; a `true` here
   downgrades the record to advisory.
3. **Two labellers per case** where the case is anything other than `easy`.
   Record disagreement as `disputed` rather than picking a winner.
4. **Never merge into `../fixtures/`.** The two directories are reported
   separately and must stay separable.

## Reporting

`score_evaluation.dart` reports `humanLabelledCaseCount` on every run. It is
currently `0`, and the report says so.
