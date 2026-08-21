# Manual Accessibility Checklist (VoiceOver / TalkBack)

This checklist covers things automated widget tests **cannot** fully verify:
real screen-reader announcement timing, real focus order under an actual
screen reader, and OS-level reduced-motion behavior. Run it on a real device
(or simulator with VoiceOver, or an Android emulator/device with TalkBack)
before shipping changes to Record, Archive, proof detail/correction, or the
paywall.

Widget-test coverage for the same flows lives in:

- `test/delete_account_confirmation_test.dart` — destructive confirmation gate.
- `test/paywall_*` / `test/subscription_*` files (~25 test files covering the
  paywall subtree) — plan-selector semantics, restore action, error live
  region.
- `test/archive_belief_*` and `test/visible_archive_proof_ui_test.dart` —
  entry card semantics, offline banner live region, proof display gating.

- `test/onboarding_simplified_test.dart` — welcome + consent semantics, text
  scale 1.0/1.3/2.0 overflow checks.
- `test/moment_save_receipt_test.dart` — unified post-save receipt actions,
  remote failure status, semantics container label.

Run each scenario twice: once with **VoiceOver** (iOS Simulator or device:
Settings → Accessibility → VoiceOver, or Cmd+F5 on Simulator) and once with
**TalkBack** (Android: Settings → Accessibility → TalkBack). Record any
divergence between platforms as a separate finding — don't assume iOS
behavior generalizes to Android or vice versa.

## 1. Setup

- [ ] Enable VoiceOver / TalkBack before opening the app (not mid-session).
- [ ] Set **text size to the largest OS setting** (iOS: Settings →
      Accessibility → Display & Text Size → largest slider step, or enable
      Larger Accessibility Sizes; Android: Settings → Accessibility → Font
      size → largest) and re-run every scenario below. Confirm no text is
      clipped, no button becomes untappable, and no row overlaps another.
- [ ] Enable **Reduce Motion** (iOS: Accessibility → Motion → Reduce Motion;
      Android: Settings → Accessibility → Remove animations) and re-check any
      screen with a custom animation (recording waveform/visualizer, the
      belief-update payoff reveal, onboarding ambient glow) for a static or
      simplified fallback instead of continuous motion.

## 2. Record screen

- [ ] Swipe through the record screen top-to-bottom with VoiceOver/TalkBack.
      Confirm the reading order matches the visual order (title → status →
      record/stop control → transcript/results). Report any control that gets
      focused out of visual sequence.
- [ ] Focus the record/stop control. Confirm it announces a real action label
      ("Start recording" / "Stop recording"), not just an icon description
      like "button" or "stop icon".
- [ ] Start a recording. Confirm the elapsed-time / recording-state
      announcement updates periodically without you needing to re-focus the
      element (live region behavior) — VoiceOver should periodically speak
      the updated time or state without extra swipes.
- [ ] Stop the recording. Confirm the transition to "processing" /
      "transcribing" state is announced, not silent.
- [ ] Trigger a recording error (e.g. deny microphone permission, or start
      recording twice rapidly). Confirm the error text is announced
      automatically (live region) rather than requiring the user to
      rediscover it by swiping.
- [ ] Confirm the record/stop control's tappable area feels reachable at the
      edge of its visual bounds — this maps to the 44pt (iOS) / 48dp
      (Android) minimum touch target enforced in code; use Accessibility
      Inspector (iOS) or TalkBack's "Explore by touch" (Android) to spot-check
      the actual hit area, since visual size and hit-test size can diverge.

## 3. Archive screen

- [ ] Swipe through an Archive entry card. Confirm VoiceOver/TalkBack reads
      one coherent label per card (title/summary + status), not a duplicated
      or fragmented announcement (e.g. the same status word spoken twice
      because both a `Semantics` wrapper and its child expose it).
- [ ] Confirm decorative icons on entry cards (chevrons, status dots) are
      silent — VoiceOver/TalkBack should not stop on them or announce
      "image"/"icon" with no useful label.
- [ ] Turn on airplane mode / disconnect network. Confirm the offline banner
      is announced automatically (live region), and re-enable network to
      confirm the banner's disappearance is also communicated in some way
      (either an announcement or the focus naturally landing back on content).
- [ ] Open an entry and reach the proof/evidence section. Confirm the
      confidence indicator (low/medium/high) is announced in words, not just
      conveyed by color.
- [ ] If the entry has a correction control, confirm activating it announces
      the confirmation dialog's title and both actions distinctly (e.g. not
      "button, button").

## 4. Proof detail / correction

- [ ] Open the correction confirmation dialog. Confirm VoiceOver/TalkBack
      moves focus into the dialog automatically and announces the dialog
      title first (not a button inside it).
- [ ] Confirm the "confirm"/"cancel" (or "delete permanently"/"cancel")
      actions are distinguishable by more than color when read aloud —
      e.g. the destructive action's label itself should say what it does.
- [ ] Dismiss the dialog via the cancel action and confirm focus returns to
      (or near) the control that opened it, rather than jumping to an
      unrelated part of the screen.

## 5. Paywall

- [ ] Open the paywall. Confirm the Pro title is the first or an early
      focusable element, not buried after several decorative elements.
- [ ] Swipe to a plan card (monthly/annual). Confirm it announces "selected"
      or "not selected" state, the plan name, and the price in one coherent
      read — not a bare "button".
- [ ] Select the other plan. Confirm the selection-state announcement updates
      when you re-focus the cards (selected/not-selected should swap).
- [ ] Focus the primary purchase button while no package has loaded yet
      (e.g. force a slow/failed network). Confirm it is either not focusable
      or clearly announces a disabled/loading state — it must never silently
      look tappable to a sighted user while being enabled for a screen-reader
      user with no real package behind it (or vice versa).
- [ ] Trigger a billing error (airplane mode). Confirm the error explanation
      is announced automatically (live region) and that "Restore purchases"
      remains reachable within a few swipes, without needing to swipe past a
      long marketing section.
- [ ] Start a purchase (sandbox/test account) and confirm the
      purchase-in-progress state is announced (e.g. "Purchasing…") and that
      the button doesn't silently disable without any spoken indication.
- [ ] If the account already has Pro, open the paywall (e.g. via a stale deep
      link) and confirm there is no purchase call-to-action announced —
      only the current-plan/entitlement state and (if present) restore.

## 6. Destructive confirmations (Delete account)

- [ ] Focus the "Delete account" button and activate it. Confirm the
      confirmation dialog's title ("Delete account permanently?") is
      announced before either action button.
- [ ] Confirm the destructive action ("Delete permanently") and "Cancel" are
      distinguishable when read aloud, and that activating "Cancel" returns
      you to the delete-account screen with no network call made (watch for
      any loading indicator — there should be none after Cancel).
- [ ] Confirm activating "Delete permanently" announces the busy/in-progress
      state, and that a resulting error (e.g. offline) is announced
      automatically rather than silently appearing as text only.

## 7. General sweep (any screen you touched)

- [ ] Tab/swipe through custom tabs, chips, or icon-only buttons. Confirm
      every one announces a real label (not "button" alone) and, for
      toggle-like controls, its current state (selected/unselected, on/off).
- [ ] Confirm no two adjacent elements repeat the exact same announcement
      (a common bug when a `Semantics` label wraps a child that already has
      its own visible text — the child's text gets read twice).
- [ ] With Reduce Motion on, confirm any custom animation you touched either
      stops, shortens drastically, or switches to a simple fade/no-op instead
      of playing its full motion.

## 8. Onboarding and post-save receipt (Command 09)

### Onboarding — two steps, no microphone

- [ ] Fresh install: Screen 1 reads **ArchiveMe**, tagline **Save the moment.
      See what returns.**, body explanation, and **Continue** in logical order.
- [ ] **Continue** moves to Screen 2 (Saving on this device) without any
      microphone permission dialog.
- [ ] Screen 2 reads local-save explanation, data-flow bullets, **See what is
      sent and when** link, then **Use remote processing** and **Keep saves on
      this device only** with equal visual weight.
- [ ] Neither consent button is pre-selected; the app does not proceed until
      one is activated.
- [ ] **See what is sent and when** opens Privacy without trapping focus or
      requiring a long legal scroll to return and choose.
- [ ] Repeat at **200% text size** (or largest accessibility size): both
      screens scroll; no clipped CTAs.

### Post-save receipt

- [ ] After first save, one receipt announces **Saved on this device**, saved
      text (if any), **Correct text**, **Record another**, **View Archive**.
- [ ] No second card announces pattern, proof, confidence, milestone, or
      pseudo-progress after a single moment.
- [ ] If remote processing fails, a secondary status is announced after the
      save confirmation; **Retry remote processing** is reachable and the
      local save is still described as successful.
- [ ] After two moments with grounded overlap, any relationship line uses
      tentative language only (may / might — not certainty).

## Filing findings

For each failed check, note: screen name, platform (iOS/Android), OS
accessibility setting in effect, exact repro steps, and what was
announced/observed vs. expected. File as a normal bug — this checklist does
not replace targeted widget-test coverage for anything it's possible to
assert automatically (see the test files listed at the top).
