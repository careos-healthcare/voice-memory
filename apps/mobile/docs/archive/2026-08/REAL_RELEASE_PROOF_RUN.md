# ArchiveMe Real Release Proof Run

## Repo proof

- [ ] `git status --short` is clean
- [ ] local branch is up to date with `origin/main`
- [ ] `bash tool/validate_core.sh` passes
- [ ] `flutter test` passes

## Build proof

- [ ] App builds for iOS release
- [ ] App installs on physical iPad
- [ ] App installs on physical iPhone if available
- [ ] App opens without crash
- [ ] App name shows as ArchiveMe
- [ ] Bundle ID is correct
- [ ] Version/build number is correct

## First journey proof

- [ ] Fresh install opens cleanly
- [ ] User understands what to do first
- [ ] Mic permission accept path works
- [ ] Mic permission deny path works
- [ ] Type instead works
- [ ] Voice recording works
- [ ] Save works
- [ ] Post-save reinforcement appears
- [ ] Prompt assist does not feel like chat
- [ ] One sentence feels enough

## Proof trail proof

- [ ] First useful proof appears after enough usable moments
- [ ] Proof copy is understandable
- [ ] Why this appeared is understandable
- [ ] Confirm/correct works
- [ ] What changed / return check works where eligible
- [ ] No dashboard/report/action-item noise appears too early

## Pro proof

- [ ] Pro promise says Free shows first useful proof
- [ ] Pro promise says Pro keeps longer proof trail
- [ ] Pro does not sound like more AI
- [ ] Pro does not sound like storage/cloud backup
- [ ] Pro CTA appears after proof value, not too early

## RevenueCat proof

- [ ] Real iOS RevenueCat API key provided
- [ ] Offering loads
- [ ] Product identifier matches App Store Connect
- [ ] Price is visible
- [ ] Purchase button opens StoreKit sheet
- [ ] Sandbox purchase succeeds
- [ ] Pro entitlement becomes active
- [ ] Pro gate unlocks
- [ ] App restart keeps entitlement
- [ ] Restore purchases works
- [ ] Restore after reinstall works if possible
- [ ] Missing product/failure copy is calm and non-crashing

## Store proof

- [ ] Support URL works
- [ ] Privacy URL works
- [ ] Terms URL works if required
- [ ] Screenshots ready
- [ ] App Store metadata ready
- [ ] TestFlight build uploaded
- [ ] Internal TestFlight install works

## Production blocker

- [ ] Stripe secret key rotated before production submission
- [ ] Stripe webhook secret rotated before production submission
- [ ] Production env updated
- [ ] Old webhook disabled
- [ ] No secret values committed
- [ ] No secret values printed in logs

## Paid beta proof

- [ ] 10–20 testers invited
- [ ] First save tracked
- [ ] First useful proof tracked
- [ ] Pro promise seen tracked
- [ ] Pro tap tracked
- [ ] Purchase started tracked
- [ ] Purchase completed tracked
- [ ] Restore attempted/tracked
- [ ] Users interviewed after proof
- [ ] Interest separated from payment proof
