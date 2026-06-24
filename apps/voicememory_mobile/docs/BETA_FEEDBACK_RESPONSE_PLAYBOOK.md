# ArchiveMe — Beta Feedback Response Playbook

Local product-readiness guide for capacity-yes TestFlight feedback. Maps repeated beta failure modes to one focused fix at a time.

**This is not PMF proof.** Use cautious language: local beta signal, suggested next fix, not enough evidence yet.

## Principles

- **Do not build all fixes at once.**
- **Use one branch per repeated failure after beta evidence.**
- **RevenueCat only after return + WTP evidence.**

RevenueCat should only be finished after return + willingness-to-pay signal. Do not enable payments while diagnosing activation issues.

---

## Failure mode table

| Beta feedback | Likely product problem | What to change | What not to change | Success signal |
| --- | --- | --- | --- | --- |
| User does not understand the app | First-session promise too broad | Tighten onboarding: **Catch the yes before it costs you.** **Save a yes moment.** **See what pulled you in.** **Review what changed.** Do not add more explanation. | Do not add backend work or new archive features | User saves first yes moment without asking what the app is for |
| User does not save first moment | First save path blocked | Fix record/start flow. CTA **Save yes moment**. Prompt: *What are you about to agree to, and what makes it hard to pause?* Reduce competing cards before first save. | Do not enable RevenueCat or payments | User saves first yes moment in first session |
| User saves once but not 3 times | Activation drop-off | Show **N of 3 yes moments saved**. Explain: *Three real moments are enough to start seeing what repeats.* One clear CTA back to Record. | Do not enable payments while fixing activation | User saves 3 yes moments and reviews the yes loop |
| User says loop is repetitive | Daily change feels generic | Sharpen daily change. Combine pull reason + outcome + later cost. Avoid repeating the same line. | Do not add AI or transcript analysis | Return users say daily change feels specific |
| User says alternatives are weak | Alternatives too generic | Improve alternative rules. Prefer selected boundary response. Match pull reason to stronger fixed response. | Do not expose private transcript text | User selects or copies a boundary response that fits |
| User returns and would pay | Paid signal may be ready | Prepare RevenueCat / paid launch **next**. Do not enable in the response branch. | Do not enable payments before return + WTP evidence | User returns, marks fit, expresses WTP — then prepare paid launch separately |
| Quick capture still felt like work | Capture path still too heavy | Reduce capture workload further. Keep quick save fixed and optional. Do not add typing or long journaling. | Do not add backend work or enable payments | User reports quick capture felt light enough to use again |

---

## Local signal mapping

| Local signal | Issue ID |
| --- | --- |
| 0 real capacity moments | `first_moment_blocked` |
| 1–2 real capacity moments | `activation_dropoff` |
| 3+ moments, fit not answered / not yet / too early | `unclear_promise` (or `repetitive_loop` if daily change dismissed) |
| 3+ moments, daily change dismissed, fit unclear | `repetitive_loop` |
| 3+ moments, pull reasons saved, boundary not selected/copied | `weak_alternative` |
| Fit fits/partly + return signal + paid intent yes/maybe | `paid_signal_ready` |
| Quick capture friction = still work | `quick_capture_still_work` |

---

## Paid intent confirmation

After users reach real capacity-loop value, ask locally whether they would pay to keep the archive improving.

- **No payment is taken in beta intent check.**
- **1 paid-intent user (yes £9.99/month) = promising but not enough for full paid launch.**
- **2–3 paid-intent users = RevenueCat readiness branch.**
- `maybe` counts as soft WTP; `not_yet` and `no` do not count as paid-ready.
- Do not say paid launch is proven.

---

## Suggested next fix labels (in-app)

Fixed copy on the capacity beta signal dashboard (Support path only — not Archive Home):

- Suggested next fix: clarify first-session promise
- Suggested next fix: improve first recording CTA
- Suggested next fix: improve 3-moment activation path
- Suggested next fix: sharpen daily change response
- Suggested next fix: sharpen alternative rules
- Suggested next fix: prepare paid launch
- Suggested next fix: reduce capture workload further

---

## Related docs

- [TESTFLIGHT_BETA_LAUNCH_PLAN.md](./TESTFLIGHT_BETA_LAUNCH_PLAN.md)
- [BETA_TESTER_MESSAGE.md](./BETA_TESTER_MESSAGE.md)
- [BETA_INTERVIEW_SCRIPT_CAPACITY.md](./BETA_INTERVIEW_SCRIPT_CAPACITY.md)

---

## Canonical identity

| Field | Value |
| --- | --- |
| App name | ArchiveMe |
| Bundle ID | `com.voicememory.mobile` |
| Support URL | https://careosapp.co.uk/archiveme-support |
| iOS workspace | `apps/voicememory_mobile/ios/Runner.xcworkspace` |
