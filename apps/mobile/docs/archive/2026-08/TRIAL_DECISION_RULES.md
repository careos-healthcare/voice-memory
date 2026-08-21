# ArchiveMe — Trial Decision Rules

After the 5-user trial, apply these rules in order. Each maps a measured outcome to
a single next action. Do not stack changes — fix the top failing rule first, then
re-run a small trial.

## Decision table

| Observed outcome | Decision / next action |
|------------------|------------------------|
| First moment saved **< 4/5** | Fix the first-record prompt (`FirstLoopStartCard` copy/clarity). Make "record one moment" more obvious and less intimidating. |
| Tomorrow check chosen **< 3/5** | Fix the first pattern + the check question. The pattern or question is not compelling enough to commit to tomorrow. |
| Return **< 3/5** but useful rating is high | Build / enable reminders. People value it but forget — turn on the reminder soft-ask and confirm scheduling works. |
| "Confusing" **> 25%** | Simplify the due card. Reduce options/words on the return-day one-tap card. |
| "Did not care" **> 25%** | Sharper questions. The next-day check is too generic — make it specific to what they recorded. |
| "Not useful" **> 30%** | Improve result interpretation. The closed-loop result/headline does not land — refine progress + result copy. |
| Useful or sort-of **≥ 3/5** AND return **≥ 3/5** | **Proceed to a wider 20-user beta.** |

## Notes
- "Useful rating high" = 3/5 or more rate useful/sort-of useful.
- If multiple rules trigger, fix the earliest (highest in the table) first; it is
  usually upstream of the others.
- Reminders are implemented and gated (Settings → "Check-in reminders" and the
  Day-0 soft-ask after choosing tomorrow's check), so the "build/enable reminders"
  action is mostly an enable + verify, not new engineering.
- Record which rule fired and the change made in the trial folder before re-testing.
