# ArchiveMe — Loop Test App Store / TestFlight copy

Draft metadata for wedge testing: **capacity_yes** vs **prove_enough**. Sharp loop promises — not generic journaling language.

---

## App subtitle options

**Capacity wedge**
- Catch yes-before-capacity loops
- Test your yes-before-capacity loop
- Record the moment you say yes too soon

**Prove-enough wedge**
- Catch proving-enough loops
- Test your proving-enough loop
- Record when stopping feels unsafe

**Generic (control)**
- Loops that repeat, change, or fade
- Short moments, repeating patterns

---

## Short description options (App Store)

### capacity_yes

ArchiveMe helps you record short moments and test whether your **yes-before-capacity** loop keeps repeating. Spot when you agree before checking your room, build a 3-moment evidence trail, and review whether the loop is getting clearer.

### prove_enough

ArchiveMe helps you record short moments and test whether your **proving-enough** loop keeps repeating. Spot when stopping feels unsafe, build a 3-moment evidence trail, and review whether effort comes from choice or pressure.

### generic

ArchiveMe remembers what keeps repeating. Record short moments. Look for loops that repeat, change, or fade — without turning your life into a journal project.

---

## Promotional text options

1. **Which loop owns you?** Test capacity-yes vs proving-enough with two sharp entry promises.
2. **Not a diary.** ArchiveMe is for loops — the moments that repeat before you notice the pattern.
3. **Three moments. One review.** Build evidence, then see if the loop is getting clearer.

---

## First screenshot captions

### capacity_yes sequence

1. **Headline:** Catch the moment you say yes before checking capacity  
   **Caption:** Record one yes moment — before the pattern disappears.

2. **Headline:** See what the yes seemed to cost  
   **Caption:** ArchiveMe reads your moment and names the loop, not a mood label.

3. **Headline:** Build a 3-moment evidence trail  
   **Caption:** Return for the next yes moment. Three recordings unlock loop review.

4. **Headline:** Review whether the loop is getting clearer  
   **Caption:** Confirm, correct, or keep watching — your call.

### prove_enough sequence

1. **Headline:** Catch the moment you do more to feel enough  
   **Caption:** Record when stopping felt uncomfortable — not when you “should” reflect.

2. **Headline:** Spot when stopping feels unsafe  
   **Caption:** ArchiveMe looks for the proving loop in what you actually said.

3. **Headline:** Build a 3-moment evidence trail  
   **Caption:** Two more proving moments. Then review the pattern together.

4. **Headline:** Review whether the loop is getting clearer  
   **Caption:** See if effort is choice or pressure — across three real moments.

---

## TestFlight — What to Test

### Cohort A: capacity_yes

**Invite route (internal):** `/start/capacity-yes`

**What to test**
- Does the yes-before-capacity promise get you to record moment 1 within 24 hours?
- After the first read, do you return for moment 2?
- Does loop review feel specific to “saying yes before checking capacity”?

**Tester task**
Use the app for two days. Record one moment where you said yes before checking capacity, then come back and record the next yes moment.

**Report back**
- What felt accurate in the first read?
- What felt off?
- Would you pay to keep reviewing this loop?

### Cohort B: prove_enough

**Invite route (internal):** `/start/prove-enough`

**What to test**
- Does the proving-enough promise get you to record moment 1 within 24 hours?
- After the first read, do you return for moment 2?
- Does loop review feel specific to “doing more to feel enough”?

**Tester task**
Use the app for two days. Record one moment where you did more because stopping felt uncomfortable, then come back and record the next proving moment.

**Report back**
- What felt accurate in the first read?
- What felt off?
- Would you pay to keep reviewing this loop?

### Cohort C: generic (control)

**Invite route (internal):** `/start/generic`

**What to test**
- Does generic “loops that repeat” copy activate as well as a sharp wedge?
- Time to first recording vs wedge cohorts.

---

## Notes for facilitators

- Routes are **in-app TestFlight helpers**, not public marketing URLs, until universal links are configured.
- Do not mix cohort invites in one group chat — assign one wedge per tester when comparing activation.
- Export trial summary after each session; check **Tester invite copy** counters in Trial Control.
