# Retirement tiers — what each one actually means
This codebase has three separate places for code that isn't part of the
current shipping app. They are not interchangeable, and the difference
matters: at least one of them (retired_sprawl) very often contains real,
live, shipping code despite its name.
## retired_sprawl/
**Not necessarily retired. Often live.** This directory is excluded from
the static analyzer and from several audit scripts, but individual
features inside it are frequently symlinked into lib/ and genuinely
shipping in production. Confirmed examples found in this codebase:
CaregiverReadService, MemoryResurfacingService, ThemeTrackerService, and
the routine-prompt engine were all found here, all live, all reachable by
real users.
scripts/validate-consent-ttl.mjs's own comment calls this correctly:
"analyzer-excluded but shipped."
**Before assuming anything in retired_sprawl/ is dead:** check whether
lib/features/<name> is a symlink into this directory
(`ls -la lib/features/` will show it), and check for real construction
sites (`grep -rn "ClassName(" lib --include="*.dart" | grep -v test`).
## deferred_v2_code/
**Genuinely deferred, not shipping.** Code intentionally scoped out of
V1 for a planned V2, not wired into any live symlink or route. Lower risk
to assume dead than retired_sprawl, but confirm with the same construction-site
check above before relying on that assumption.
## attic/
**Genuinely archived.** Code kept for historical/reference reasons, not
part of any current or planned near-term roadmap. Lowest-risk tier to
treat as inert.
## The actual rule
Never assume "location implies status." Every claim about whether
something in any of these three directories is live or dead should be
verified the same way: find every real construction site of the class in
question outside of tests, and trace it through to an actual mounted
screen, an actual capability flag's real value, and an actual route
allowlist entry. All three have to check out for something to be
genuinely reachable by a user today.
