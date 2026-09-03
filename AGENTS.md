<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Claim widgets need a reachable evidence link

Any new widget displaying a pattern, belief-change, or confidence claim to the
user should include a reachable evidence link, per the pattern in
`ViewEvidenceInlineLink`. Audit periodically against `archive_insight_feedback`
/ `pattern_confidence` / `pattern_lifecycle` as reference implementations.

There is no automated gate for this. Word scans are noisy; type scans
false-positive parents that compose a badge. The next audit should start from
these three, not rediscover the pattern:

- `apps/mobile/lib/widgets/archive/view_evidence_inline_link.dart`
- `apps/mobile/lib/widgets/archive/archive_insight_feedback_controls.dart`
- `apps/mobile/lib/widgets/patterns/pattern_confidence_badge.dart`
- `apps/mobile/lib/widgets/patterns/pattern_lifecycle_badge.dart`

## Widget tests: fake async vs real IO

A widget test that constructs a real `JournalStore` / `MobilePrefsStore` /
coordinator that performs file I/O must use `tester.runAsync()` or an injected
fake — never a bare `await` in a standard widget-test body. The fake async
clock never completes those Futures (`pattern_name_test`, #268 / #269 prefs
races, #300 `GuestDataMigrationScreen`). `pumpAndSettle` against the leftover
`CircularProgressIndicator` then hits the 10-minute `TimeoutException`.
