#!/usr/bin/env python3
"""Generate APP22 desktop export — documentation only, no repo changes."""

from __future__ import annotations

import os
import re
import subprocess
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

MOBILE = Path(__file__).resolve().parents[1]
REPO = MOBILE.parent.parent
OUT = Path.home() / "Desktop" / "APP22"

SKIP_DIR_NAMES = {
    ".dart_tool",
    "build",
    "Pods",
    "DerivedData",
    "node_modules",
    ".git",
    "ios/Pods",
    "android/.gradle",
}
SKIP_SUFFIXES = {".tmp", ".m4a", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".lock"}
MAX_EXCERPT_LINES = 90
MAX_FILE_LIST_PER_DIR = 500


def run(cmd: list[str], cwd: Path | None = None) -> str:
    return subprocess.check_output(cmd, cwd=cwd or REPO, text=True, stderr=subprocess.STDOUT).strip()


def git_meta() -> dict[str, str]:
    return {
        "commit": run(["git", "rev-parse", "HEAD"]),
        "branch": run(["git", "branch", "--show-current"]),
        "status": run(["git", "status", "--short"]),
        "log30": run(["git", "log", "-30", "--oneline"]),
    }


def header(title: str, meta: dict[str, str]) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    return (
        f"{'=' * 72}\n"
        f"{title}\n"
        f"{'=' * 72}\n"
        f"Export timestamp: {ts}\n"
        f"Git branch: {meta['branch']}\n"
        f"Git commit: {meta['commit']}\n"
        f"Repo root: {REPO}\n"
        f"Mobile app: {MOBILE}\n"
        f"\nGIT STATUS (short)\n{'-' * 40}\n"
        f"{meta['status'] or '(clean working tree for tracked files)'}\n"
        f"{'=' * 72}\n\n"
    )


def read_text(path: Path, max_lines: int | None = None) -> str:
    if not path.is_file():
        return f"[MISSING: {path}]\n"
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        return f"[READ ERROR: {path}: {exc}]\n"
    if max_lines is not None:
        lines = lines[:max_lines]
    return "\n".join(lines) + ("\n" if lines else "")


def excerpt(path: Path, label: str | None = None, max_lines: int = MAX_EXCERPT_LINES) -> str:
    rel = path.relative_to(REPO) if path.is_relative_to(REPO) else path
    body = read_text(path, max_lines)
    truncated = ""
    try:
        total = len(path.read_text(encoding="utf-8", errors="replace").splitlines())
        if total > max_lines:
            truncated = f"\n... [{total - max_lines} more lines truncated]\n"
    except OSError:
        pass
    title = label or str(rel)
    return f"\n--- EXCERPT: {title} ---\nPath: {rel}\n{body}{truncated}"


def list_dart_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES and not d.startswith(".")]
        for name in filenames:
            if name.endswith(".dart") and not any(name.endswith(s) for s in SKIP_SUFFIXES):
                files.append(Path(dirpath) / name)
    return sorted(files)


def dart_symbols(path: Path) -> list[str]:
    if not path.is_file():
        return []
    symbols: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"^\s*(?:abstract\s+)?(?:final\s+)?class\s+(\w+)", line)
        if m:
            symbols.append(f"class {m.group(1)}")
            continue
        m = re.match(r"^\s*enum\s+(\w+)", line)
        if m:
            symbols.append(f"enum {m.group(1)}")
    return symbols[:8]


def feature_dirs() -> list[str]:
    feat = MOBILE / "lib" / "features"
    if not feat.is_dir():
        return []
    return sorted(d.name for d in feat.iterdir() if d.is_dir())


def write_file(name: str, content: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    path.write_text(content, encoding="utf-8")
    return path


def generate_01(meta: dict[str, str]) -> str:
    s = header("01 — PROJECT OVERVIEW, STATUS, AND ROADMAP", meta)
    s += """PRODUCT
-------
Name: ArchiveMe (VoiceMemory repo / bundle com.voicememory.mobile)
Purpose: Private local-first voice-and-text journal that compares saved moments
over time — evidence from the user's own words, not therapy or diagnosis.

NORTH STAR
----------
Record one real moment. Return when it repeats. See the evidence.
Keep the longer trail with Pro.

STRATEGIC PRODUCT PRINCIPLE
---------------------------
"Record one real moment. Return when it repeats. See the evidence.
Keep the longer trail with Pro."

CORE LOOP
---------
1. Save one real moment (voice or typed).
2. Come back when the same thread shows up again.
3. Record whether it came back, changed, faded, or disappeared.
4. Archive tab shows cautious comparison from saved words only.
5. Pro (after proof milestones) keeps longer evidence history.

CURRENT APP STATUS
------------------
- iOS App Store resubmission cycle in progress
- Core loop copy and UI simplified for App Review
- 3-tab shell: Record / Archive / Account
- RevenueCat configured in dev builds; App Store product fetch still failing
- Pro/paywall gated until first repeat + evidence trail opened (commit 0098c3e5)

CURRENT BRANCH AND LATEST COMMIT
--------------------------------
See header above.

LATEST 30 GIT COMMITS
---------------------
"""
    s += meta["log30"] + "\n\n"
    s += """RECENT COMMIT THEMES (summary)
-----------------------------
- Record first-run simplification: promise card, Record moment / Type instead only
- Type instead: focused one-sentence capture on iPad
- First-save / one-entry calm state: "Come back when this shows up again"
- Archive two-entry first comparison: grounded vs weak fallback
- Returning Record watch-target: Did this come back? + 3 CTAs + Not today
- Transcript-pending recovery: single recovery path post-save
- Paywall App Review compliance: subscription details, Terms/Privacy links
- Comparison engine prompt guardrails (mobile + web parity)
- Pro/paywall delayed until first repeat and evidence trail seen

CURRENT APP STORE READINESS
---------------------------
- App Review access path: Settings → App Review Access → ARCHIVEME-REVIEW-2026
- Sample Archive + Help Reviewer Guide routes available
- Microphone pre-prompt uses "Use voice to record" (not Allow/OK)
- Paywall shows subscription title, length, price placeholder, Terms, Privacy
- App icons regenerated from master asset
- Privacy/support URLs must be live before resubmission

CURRENT LAUNCH BLOCKERS
-----------------------
1. Privacy URL live check: https://careosapp.co.uk/archiveme-privacy
2. Support URL live check: https://careosapp.co.uk/archiveme-support
3. RevenueCat CONFIGURATION_ERROR — products not fetchable from App Store Connect
   (terminal evidence: offerings=0, packageCount=0, billingConfigured=true)
4. App Store Connect subscription metadata must match in-app paywall
5. Physical device smoke + TestFlight QA
6. Secrets rotation gate before production (docs/SECRETS_ROTATION_LAUNCH_GATE.md)

CURRENT REVENUE-READINESS ASSESSMENT
------------------------------------
- Paid reason: longer evidence trail, not more AI (ProValueCopy)
- Paywall unavailable state works when products missing
- Restore purchases path wired independently of plan cards
- Delayed paywall: no upgrade pitch before proof milestones
- Store readiness classifier: docs/STORE_READINESS_SINGLE_SOURCE.md (12 steps)
- Broad paid growth deferred until core loop + purchase proof

CURRENT UI OPTIMISATION STATUS
------------------------------
- First-run Record stripped to hero + 2 capture CTAs
- Returning Record focused on watch target; streak/homework suppressed after Not today
- Archive tab four-state scaffold (0/1/2/3+ entries)
- Paywall compact: headline + subscription details + restore + continue without Pro
- Surface priority engine caps card clutter on Record and Archive

CURRENT PRODUCT ROADMAP
-----------------------
Post-V1 ideas gated in docs/FUTURE_EXPANSION_ROADMAP.md:
  Loop packs, 3-day challenge, referrals, Android after iOS proof, cross-device,
  private reports, safe exports, B2B wedge, premium tiers, etc.
Decision gate: expansionFrozen | documentedOnly | postV1PlanningAllowed
Prerequisites: TestFlight, purchase/restore/entitlement, paid-intent beta, first proof rate

KEY DOC PATHS
-------------
apps/voicememory_mobile/docs/APP_REVIEW_NOTES.md
apps/voicememory_mobile/docs/app_review_response_notes.md
apps/voicememory_mobile/docs/IOS_RELEASE_CHECKLIST.md
apps/voicememory_mobile/docs/STORE_READINESS_SINGLE_SOURCE.md
apps/voicememory_mobile/docs/FUTURE_EXPANSION_ROADMAP.md
apps/voicememory_mobile/docs/revenue/PAID_REASON_V1.md
apps/voicememory_mobile/docs/STICKY_LOOP_PRODUCT_MAP.md
"""
    s += excerpt(MOBILE / "pubspec.yaml", max_lines=12)
    return s


def generate_02(meta: dict[str, str]) -> str:
    s = header("02 — RECORD CAPTURE AND RETURNING FLOW", meta)
    s += """OVERVIEW
--------
Primary tab: /record → lib/screens/record_screen.dart
Capture modes: voice (mic permission path) and typed (/quick-capture)

RECORD TAB STATES
-----------------
1. First-run Record (0 entries)
   - Hero: How ArchiveMe works / promise steps
   - CTAs: Record moment | Type instead
   - Gate: RecordEmptyArchiveGates.showFirstUseSimplifiedRecord

2. Type instead (/quick-capture)
   - lib/screens/quick_text_capture_screen.dart
   - Focused one-sentence capture; no mic required

3. Voice capture
   - Pre-prompt: "Use voice to record" (App Review 5.1.1 compliance)
   - lib/features/voice_capture/ — permission, audio, transcription

4. Returning Record with watch target
   - Title: Did this come back?
   - Footer: Record if it came back, changed, faded, or disappeared.
   - CTAs: Record what happened | Type instead | Not today
   - Gates: ReturningRecordWatchTargetUiGates

5. Not today path
   - Dismisses watch card cleanly; no streak warnings
   - suppressDailyStreakPressureToday() hides homework/framing

6. Transcript-pending recovery
   - When newest entry lacks transcript
   - Single recovery path post-save; Archive pending view

7. Post-save state (RecordUiState.done)
   - First save: FirstSaveEvidenceCard — Saved / Come back when this shows up again
   - Repeat save: repeat proof card
   - Card stack limited by RecordProofStackPolicy + SurfacePriorityEngine

KEY DART FILES
--------------
lib/screens/record_screen.dart
lib/screens/quick_text_capture_screen.dart
lib/features/record/record_empty_archive_gates.dart
lib/features/record/returning_record_watch_target_ui_gates.dart
lib/features/daily_archive_memory/daily_archive_memory_copy.dart
lib/features/daily_archive_memory/daily_archive_memory_engine.dart
lib/widgets/record/daily_archive_memory_card.dart
lib/widgets/onboarding/first_save_evidence_card.dart
lib/features/archive_proof/visible_archive_proof_copy.dart
lib/features/voice_capture/microphone_permission_policy.dart
lib/widgets/record/pending_transcript_recovery_prompt.dart
lib/widgets/record/pending_transcript_recovery_sheet.dart
lib/features/trust/pending_transcript_recovery_gate.dart

IMPORTANT COPY STRINGS
----------------------
"""
    s += excerpt(MOBILE / "lib/features/archive_proof/visible_archive_proof_copy.dart", "first-run + first-save copy", 100)
    s += excerpt(MOBILE / "lib/features/daily_archive_memory/daily_archive_memory_copy.dart", max_lines=35)
    s += excerpt(MOBILE / "lib/features/record/returning_record_watch_target_ui_gates.dart", max_lines=55)
    s += """
APP REVIEW MICROPHONE COMPLIANCE
--------------------------------
- Permission button: "Use voice to record" (not "Allow" / "OK")
- Type instead always available without microphone
- See test/microphone_permission_compliance_test.dart (if present)

RELEVANT TESTS
--------------
test/returning_record_watch_target_test.dart — watch target UI, Not today, CTAs
test/daily_archive_memory_test.dart — watch copy integration
test/core_loop_return_clarity_test.dart — core loop copy alignment
test/one_entry_post_save_copy_test.dart — first-save calm state
test/record_return_pro_loop_test.dart — record return loop
test/first_three_session_loop_test.dart — early session loop
test/degraded_voice_first_save_test.dart — voice degradation path
integration_test/production_ui_verify_test.dart — production UI smoke
"""
    return s


def generate_03(meta: dict[str, str]) -> str:
    s = header("03 — ARCHIVE PROOF, COMPARISON, AND EVIDENCE FLOW", meta)
    s += """ARCHIVE TAB STATE MAP
---------------------
Route: /archive-belief → lib/screens/archive_belief_screen.dart
Engine: lib/features/archive_tab/archive_tab_four_state_engine.dart

0 entries — empty archive preview, Record moment CTA
1 entry — "Your archive has started" / Come back when this shows up again
2 unrelated entries — weak comparison fallback (no repeat claim)
2 related entries — first comparison card (grounded repeat)
3+ entries — mature archive: belief forming, evidence trail, weekly review (gated)

STRONG COMPARISON COPY (grounded)
---------------------------------
Title: This looks like it came back.
Bodies (one of):
  - You mentioned something similar before.
  - This may be the same thread as an earlier saved moment.
  - This looks like it came back, but ArchiveMe needs more moments to be sure.
Evidence line: from SecondSessionSignalEngine (user's saved words)

WEAK FALLBACK COPY (no grounded repeat)
--------------------------------------
Title: ArchiveMe has two moments to compare.
Body: No clear repeat yet. One more moment will make the thread easier to see.

EVIDENCE TRAIL FLOW
-------------------
lib/features/evidence_trail/evidence_trail_navigation.dart
  showEvidenceTrailSheet() — also marks hasOpenedEvidenceTrail for paywall gate
lib/features/belief_evidence/
lib/screens/belief_evidence_screen.dart

THOUGHT MAP VISIBILITY
----------------------
Confirmed-repeat thought map gated — not shown at weak comparison
lib/features/archive_thought_map/archive_thought_map_engine.dart
lib/features/early_archive/confirmed_repeat_thought_map_engine.dart

KEY FILES
---------
lib/features/archive_proof/archive_first_comparison_display.dart
lib/features/archive_proof/archive_first_comparison_ui_gates.dart
lib/widgets/archive/archive_first_comparison_card.dart
lib/features/retention/second_session_signal_engine.dart
lib/features/archive_proof/visible_archive_proof_copy.dart
lib/features/comparison_engine/comparison_engine.dart

HOW GROUNDED REPEAT CHECKS WORK
-------------------------------
SecondSessionSignalEngine.hasGroundedRepeatMatch(entries) required for strong UI.
ComparisonEngine.build() returns unrelated if no grounded match.
ArchiveEvidenceGuard + ArchiveEvidenceQualityGate filter placeholder/pending entries.
Banned generic insight framing via ComparisonEnginePrompt.sanitizeLine().

KEY EXCERPTS
------------
"""
    s += excerpt(MOBILE / "lib/features/archive_proof/archive_first_comparison_display.dart")
    s += excerpt(MOBILE / "lib/features/retention/second_session_signal_engine.dart", max_lines=70)
    s += excerpt(MOBILE / "lib/features/comparison_engine/comparison_engine.dart", max_lines=80)
    s += """
RELEVANT TESTS
--------------
test/archive_first_comparison_test.dart
test/archive_first_comparison_card_test.dart
test/first_archive_state_test.dart
test/second_session_signal_engine_test.dart
test/core_loop_return_clarity_test.dart
test/delayed_paywall_proof_test.dart — evidence trail milestone
"""
    return s


def generate_04(meta: dict[str, str]) -> str:
    s = header("04 — COMPARISON ENGINE PROMPT GUARDRAILS AND MODEL OUTPUT", meta)
    s += """PROMPT CONTRACT
---------------
Banned phrase prefixes (never start with or use):
  - "You always..."
  - "This means..."
  - "Your pattern is..."
  - "You have a deep fear of..."

Allowed confidence labels (exactly one):
  Early signal, Possible repeat, Clear repeat, Still current, Fading,
  Changed, Softened, Corrected, Not enough evidence

Required output elements (in order):
  1. What appears to have repeated (cautious, grounded)
  2. Which saved moment it connects to (day and time)
  3. What changed (if known; omit when unknown)
  4. Thin-evidence caution when needed

Default thin-evidence phrase:
  "ArchiveMe needs more moments to be sure."

STRUCTURED OUTPUT (Dart)
------------------------
ComparisonEngineOutput.formatStructuredSummary() example shape:
  Confidence: Clear repeat
  What appears to have repeated: <line>
  Connects to: <day/time label>
  What changed: <line>   (optional)
  ArchiveMe needs more moments to be sure.   (optional)

MOBILE IMPLEMENTATION
---------------------
lib/features/comparison_engine/comparison_engine_prompt.dart
lib/features/comparison_engine/comparison_engine_model.dart
lib/features/comparison_engine/comparison_engine.dart

WEB PARITY
----------
lib/comparison/comparison-engine-prompt.ts
lib/reliability/comparison-engine-prompt-tests.ts

KEY EXCERPTS — MOBILE
---------------------
"""
    s += excerpt(MOBILE / "lib/features/comparison_engine/comparison_engine_prompt.dart")
    s += excerpt(MOBILE / "lib/features/comparison_engine/comparison_engine_model.dart")
    s += excerpt(REPO / "lib/comparison/comparison-engine-prompt.ts", "web parity prompt", 55)
    s += """
RELEVANT TESTS
--------------
apps/voicememory_mobile/test/comparison_engine_test.dart (if present)
lib/reliability/comparison-engine-prompt-tests.ts (web)
apps/voicememory_mobile/test/core_loop_return_clarity_test.dart
"""
    return s


def generate_05(meta: dict[str, str]) -> str:
    s = header("05 — PRO, PAYWALL, REVENUECAT, AND SUBSCRIPTIONS", meta)
    s += """CURRENT PAYWALL UI
----------------
Route: /subscription → lib/screens/paywall_screen.dart
Headline: Free shows the first useful proof. Pro keeps the longer trail.
Subhead: Pro keeps longer evidence history, weekly archive reviews, and timeline views.
Unavailable: compact fallback + subscription details + restore + Continue without Pro
Available: monthly/yearly plan cards when RevenueCat packages load

APP REVIEW COMPLIANT SUBSCRIPTION DETAILS
-----------------------------------------
lib/widgets/billing/paywall_subscription_details_section.dart
  - Subscription title (ArchiveMe Pro)
  - Length (monthly / yearly auto-renew)
  - Price from StoreKit when available
  - Terms of Use link (Apple Standard EULA)
  - Privacy Policy link → AppConfig.privacyUrl

ENTITLEMENT IDENTIFIER
----------------------
Primary: archive_loop_pro (ArchiveLoopEntitlementIds)
Legacy honored: pro (RevenueCatService.proEntitlementId)

PRODUCT IDS (App Store Connect / RevenueCat)
--------------------------------------------
Documented in release checklists and user-facing docs:
  com.archiveme.app.monthly
  com.archiveme.app.yearly
Code canonical references (PackageType selection):
  archive_loop_pro_monthly
  archive_loop_pro_yearly
RevenueCat offering expectations:
  Offering identifier: default (current offering)
  Package identifiers: $rc_monthly, $rc_annual (RevenueCat standard)

KNOWN BLOCKER (device terminal evidence, Jul 2026)
--------------------------------------------------
RevenueCat configured successfully (billingConfigured=true)
PlatformException CONFIGURATION_ERROR (code 23):
  None of the products registered in the RevenueCat dashboard could be fetched
  from App Store Connect.
Result: offerings=0, packageCount=0, purchasePlansAvailable=false
Likely cause: App Store Connect subscription review / product linkage / banking

PAYWALL GATING (commit 0098c3e5)
--------------------------------
Pro bridge AND paywall blocked until BOTH milestones:
  - hasSeenFirstRepeat (first repeat proof seen)
  - hasOpenedEvidenceTrail (evidence trail sheet opened)
Store: lib/features/pro_bridge_visibility/delayed_paywall_proof_store.dart
PaywallAccess.canOpenPaywall() / PaywallScreen gate on /subscription

RESTORE PURCHASES
-----------------
lib/billing/restore_purchases_flow.dart
Visible on paywall even when plans unavailable

CONTINUE WITHOUT PRO
------------------
ProPackagingCopy.continueWithoutProCta / paywall dismiss capture

TERMS AND PRIVACY LINKS
-----------------------
AppConfig.privacyUrl = https://careosapp.co.uk/archiveme-privacy
AppConfig.supportUrl = https://careosapp.co.uk/archiveme-support
Terms: Apple Standard EULA URL in paywall subscription details

KEY EXCERPTS
------------
"""
    s += excerpt(MOBILE / "lib/features/pro_value/pro_value_copy.dart")
    s += excerpt(MOBILE / "lib/features/pro_bridge_visibility/delayed_paywall_proof_store.dart")
    s += excerpt(MOBILE / "lib/billing/paywall_access.dart", max_lines=95)
    s += excerpt(MOBILE / "lib/billing/archive_loop_entitlement_ids.dart")
    s += excerpt(MOBILE / "lib/config/app_config.dart", "URLs only", 30)
    s += """
RELEVANT TESTS (recent focused suite: 84/84 passed)
---------------------------------------------------
test/delayed_paywall_proof_test.dart
test/paywall_alignment_test.dart
test/paywall_copy_alignment_test.dart
test/paywall_value_sharpening_test.dart
test/pro_packaging_test.dart
test/pro_bridge_visibility_lift_test.dart
integration_test/revenuecat_e2e_audit_test.dart
integration_test/revenuecat_production_evidence_test.dart
"""
    return s


def generate_06(meta: dict[str, str]) -> str:
    s = header("06 — APP REVIEW, iOS SUBMISSION, AND METADATA", meta)
    s += read_text(MOBILE / "docs/app_review_response_notes.md", 130)
    s += "\n--- APP_REVIEW_NOTES.md (excerpt) ---\n"
    s += read_text(MOBILE / "docs/APP_REVIEW_NOTES.md", 90)
    s += "\n--- IOS_RELEASE_CHECKLIST.md (excerpt) ---\n"
    s += read_text(MOBILE / "docs/IOS_RELEASE_CHECKLIST.md", 70)
    s += """
APPLE REJECTION REASONS ADDRESSED
---------------------------------
1. App completeness / demo access → App Review Access code + Sample Archive
2. Placeholder app icon → regenerated from app_icon_master_1024.png
3. Subscription metadata (3.1.2c) → paywall subscription details section
4. Microphone permission wording (5.1.1) → "Use voice to record" pre-prompt
5. Privacy/support URL issues → canonical careosapp.co.uk URLs in AppConfig

APP REVIEW ACCESS FLOW
----------------------
Code: ARCHIVEME-REVIEW-2026
Where: Settings → App Review Access section
Unlocks: Pro entitlement + demo/sample archive state
Dart-define: ARCHIVEME_APP_REVIEW_MODE=true
Files:
  lib/features/app_review/archive_app_review_access_gate.dart
  lib/features/app_review/archive_app_review_access.dart
  lib/widgets/settings/app_review_access_settings_section.dart
  test/app_review_access_test.dart

REQUIRED METADATA URLS (confirm live before submit)
---------------------------------------------------
Privacy: https://careosapp.co.uk/archiveme-privacy
Support: https://careosapp.co.uk/archiveme-support
Terms: Apple Standard EULA (linked from paywall)

iOS BUILD / ARCHIVE / UPLOAD
----------------------------
cd apps/voicememory_mobile
flutter pub get && cd ios && pod install && cd ..
flutter build ios --release \\
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
Open ios/Runner.xcworkspace in Xcode → Product → Archive → Distribute

Xcode workspace: apps/voicememory_mobile/ios/Runner.xcworkspace
Bundle ID: com.voicememory.mobile

iPad / device install workaround
--------------------------------
If TestFlight/device install fails, use Xcode Cmd+R direct run to device.

FINAL RESUBMISSION CHECKLIST
----------------------------
[ ] Privacy URL loads in Safari
[ ] Support URL loads in Safari
[ ] App Review code unlocks Pro + sample content
[ ] First-run Record shows 2 CTAs only
[ ] Microphone pre-prompt copy correct
[ ] Paywall shows subscription details even when products unavailable
[ ] Restore purchases button visible
[ ] RevenueCat products fetch on device (monthly + annual packages)
[ ] Screenshots captured per docs/SCREENSHOT_CAPTURE_PLAN.md
"""
    s += excerpt(MOBILE / "lib/features/app_review/archive_app_review_access_gate.dart", max_lines=45)
    return s


def generate_07(meta: dict[str, str]) -> str:
    dirs = feature_dirs()
    s = header("07 — FEATURE MODULES, GATES, AND PRODUCT LOGIC", meta)
    s += f"Total lib/features modules: {len(dirs)}\n\n"
    s += """ACTIVE IN V1 (primary user-facing)
--------------------------------
archive_proof, daily_archive_memory, early_archive, activation, onboarding,
record, record_capture_modes, retention, patterns, archive_evidence,
archive_home, archive_tab, paywall, pro_packaging, pro_value, pro_bridge_visibility,
app_review, post_save, next_action, surface_priority, archive_thought_map,
belief_evidence, privacy_trust, comparison_engine, evidence_trail, voice_capture

GATED / DEFERRED
----------------
Modules ending in _future (documented only, no live V1 UI)
beta/* — requires ARCHIVEME_BETA_MISSION dart-define
debug/*, internal routes — developer only
Future expansion gate: docs/FUTURE_EXPANSION_ROADMAP.md

BETA / DEV / REVIEW-ONLY
------------------------
ARCHIVEME_APP_REVIEW_MODE — review access UI, suppresses beta clutter
ARCHIVEME_TRIAL_MODE — local trial without billing
VM_DEBUG_TOOLS — debug tooling routes
VOICE_MEMORY_SCREENSHOT_MODE — screenshot/demo builds
/testing-archiveme, /help-reviewer-guide — reviewer helpers

SURFACE PRIORITY / CARD CAPS
----------------------------
lib/features/surface_priority/surface_priority_engine.dart
lib/features/early_archive/record_proof_stack_policy.dart

KEY GATES
---------
RecordEmptyArchiveGates — first-run simplified Record
ReturningRecordWatchTargetUiGates — watch target + Not today streak suppress
DelayedPaywallProofStore — Pro bridge + paywall after proof milestones
ArchiveFirstComparisonUiGates — 2-entry comparison card
ArchiveEvidenceQualityGate — pending transcript / placeholder filtering
ArchiveAppReviewAccessGate — review code unlock
PaywallTimingGates — soft Pro bridge timing (entry count + proof)
ProBridgeVisibilityEngine — post-proof Pro bridge card visibility

FEATURE FLAGS / DART-DEFINES
----------------------------
VOICE_MEMORY_API_BASE_URL — backend for transcribe/analyze
REVENUECAT_IOS_API_KEY / REVENUECAT_ANDROID_API_KEY — billing (secret at build)
ARCHIVEME_APP_REVIEW_MODE, ARCHIVEME_TRIAL_MODE, ARCHIVEME_BETA_MISSION
VOICE_MEMORY_SCREENSHOT_MODE — demo/screenshot builds
VM_DEBUG_TOOLS

FULL FEATURE MODULE INDEX
-------------------------
"""
    for i, d in enumerate(dirs, 1):
        s += f"{i:3}. lib/features/{d}/\n"
    s += "\nKEY GATE EXCERPTS\n-----------------\n"
    s += excerpt(MOBILE / "lib/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart", max_lines=50)
    s += excerpt(MOBILE / "lib/features/activation/paywall_timing_gates.dart", max_lines=45)
    s += excerpt(MOBILE / "lib/features/archive_proof/archive_first_comparison_ui_gates.dart", max_lines=40)
    return s


def generate_08(meta: dict[str, str]) -> str:
    s = header("08 — UI SCREEN MAP, COPY, AND NAVIGATION", meta)
    s += """BOTTOM NAV (MainShell)
--------------------
Record     → /record          → RecordScreen
Archive    → /archive-belief  → ArchiveBeliefScreen
Account    → /account         → AccountScreen

KEY ROUTES (app_router.dart)
----------------------------
/onboarding, /quick-capture, /entry/:id, /subscription, /pricing,
/pro-preview, /sample-archive, /help-reviewer-guide, /settings,
/privacy, /terms, /restore-purchases, /testing-archiveme

SCREEN-BY-SCREEN COPY MAP
-------------------------
First-run Record:
  VisibleArchiveProofCopy.firstRunPromiseSteps
  CTAs: Record moment | Type instead

Type instead (/quick-capture):
  quick_text_capture_screen.dart — focused single-sentence entry

After first save (Record post-save):
  Saved. / Come back when this shows up again.
  Done for today | View archive | Record if it happens again

One-entry Archive:
  Your archive has started / Come back when this shows up again

Two-entry Archive (weak):
  No clear repeat yet. One more moment will make the thread easier to see.

Two-entry Archive (strong):
  This looks like it came back. + evidence from saved words

Returning watch-target Record:
  Did this come back? + watch phrase quote
  Record what happened | Type instead | Not today

Transcript pending:
  patterns_transcript_pending_view.dart + recovery prompt/sheet

Paywall available:
  ProValueCopy headline + plan cards + subscription details

Paywall unavailable:
  Purchases are not available right now + Try again + Continue without Pro

INTENTIONALLY HIDDEN ON KEY SCREENS
------------------------------------
First-run: Day 1 of 7, complex tagging, beta clutter (App Review)
Returning watch target: generic record title, homework, streak pressure
Before proof milestones: Pro bridge card, paywall navigation
Weak comparison: thought map, repeat claims

COPY SOURCE FILES
-----------------
lib/features/archive_proof/visible_archive_proof_copy.dart
lib/product/consumer_ui_copy.dart
lib/features/pro_value/pro_value_copy.dart
lib/features/daily_archive_memory/daily_archive_memory_copy.dart
lib/billing/archive_paywall_copy.dart
lib/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart

KEY EXCERPTS
------------
"""
    s += excerpt(MOBILE / "lib/widgets/main_shell.dart", max_lines=55)
    s += excerpt(MOBILE / "lib/router/app_router.dart", "routes excerpt", 80)
    s += excerpt(MOBILE / "lib/product/consumer_ui_copy.dart", "nav + paywall", 80)
    return s


def generate_09(meta: dict[str, str]) -> str:
    lib_tests = list_dart_files(MOBILE / "test")
    int_tests = list_dart_files(MOBILE / "integration_test")
    s = header("09 — TESTS, VALIDATION, KNOWN FAILURES, AND LAUNCH CHECKLIST", meta)
    s += f"Unit/widget test files: {len(lib_tests)}\n"
    s += f"Integration test files: {len(int_tests)}\n\n"
    s += """RECENTLY RUN FOCUSED SUITES (Jul 2026 export session)
-------------------------------------------------------
Delayed paywall + paywall copy suite: 84/84 passed
  test/delayed_paywall_proof_test.dart
  test/pro_bridge_visibility_lift_test.dart
  test/pro_packaging_test.dart
  test/paywall_copy_alignment_test.dart
  test/paywall_value_sharpening_test.dart
  test/paywall_alignment_test.dart
  test/pro_value_packaging_test.dart

Returning Record / watch target suite: 28/28 passed (prior session)
  test/returning_record_watch_target_test.dart
  test/daily_archive_memory_test.dart

IMPORTANT TEST FILES BY AREA
----------------------------
Record/capture:
  test/returning_record_watch_target_test.dart
  test/core_loop_return_clarity_test.dart
  test/one_entry_post_save_copy_test.dart
  test/record_return_pro_loop_test.dart
  test/first_three_session_loop_test.dart

Archive/comparison:
  test/archive_first_comparison_test.dart
  test/archive_first_comparison_card_test.dart
  test/first_archive_state_test.dart
  test/second_session_signal_engine_test.dart

Paywall/RevenueCat:
  test/delayed_paywall_proof_test.dart
  test/paywall_alignment_test.dart
  test/revenuecat_sandbox_proof_test.dart
  integration_test/revenuecat_e2e_audit_test.dart

App Review:
  test/app_review_access_test.dart
  test/ios_testflight_submission_readiness_test.dart

KNOWN BROAD-FILTER / PRE-EXISTING NOISE
---------------------------------------
- Full `flutter test` suite is large (~846 files); some legacy tests expect old copy
- Broad `--name paywall` may hit tangential copy drift tests
- RevenueCat E2E requires device + sandbox credentials + live products
- Archive collections / evidence trail tests may fail if fixtures drift

RECOMMENDED FINAL TEST COMMANDS
-------------------------------
cd apps/voicememory_mobile
flutter test test/returning_record_watch_target_test.dart test/daily_archive_memory_test.dart
flutter test test/core_loop_return_clarity_test.dart test/archive_first_comparison_test.dart
flutter test test/comparison_engine_test.dart
flutter test test/delayed_paywall_proof_test.dart test/paywall_alignment_test.dart
flutter test test/app_review_access_test.dart
flutter test test/microphone_permission_compliance_test.dart
flutter build ios --release --dart-define=VOICE_MEMORY_API_BASE_URL=...

MANUAL QA CHECKLIST
-------------------
[ ] First-run Record — 2 CTAs only
[ ] Type instead — save one sentence
[ ] Voice capture — mic pre-prompt + transcribe
[ ] Transcript pending — recovery path visible
[ ] First save post-save — calm copy, Done for today
[ ] Archive 1 entry — come back message
[ ] Archive 2 related — grounded comparison
[ ] Archive 2 unrelated — weak fallback
[ ] Returning watch target — 3 CTAs + Not today dismiss
[ ] Paywall unavailable — no blank UI, restore visible
[ ] Paywall gating — no paywall before repeat + evidence trail
[ ] App Review access — code unlocks Pro
[ ] Restore purchases — button works when configured

INTEGRATION TEST FILES
----------------------
"""
    for f in int_tests:
        s += f"  {f.relative_to(MOBILE)}\n"
    return s


def generate_10(meta: dict[str, str]) -> str:
    s = header("10 — FULL DART CODE INDEX AND KEY EXCERPTS", meta)
    for label, root in [
        ("lib/", MOBILE / "lib"),
        ("test/", MOBILE / "test"),
        ("integration_test/", MOBILE / "integration_test"),
    ]:
        files = list_dart_files(root)
        s += f"\n{'=' * 60}\n{label} — {len(files)} Dart files\n{'=' * 60}\n"
        by_dir: dict[str, list[Path]] = defaultdict(list)
        for f in files:
            rel = f.relative_to(MOBILE)
            parts = rel.parts
            if len(parts) >= 3 and parts[0] == "lib" and parts[1] == "features":
                key = f"lib/features/{parts[2]}"
            elif len(parts) >= 2:
                key = f"{parts[0]}/{parts[1]}"
            else:
                key = parts[0]
            by_dir[key].append(f)
        for key in sorted(by_dir.keys()):
            paths = by_dir[key]
            s += f"\n[{key}] ({len(paths)} files)\n"
            for p in paths[:MAX_FILE_LIST_PER_DIR]:
                rel = p.relative_to(MOBILE)
                syms = dart_symbols(p)
                sym_str = f" — {', '.join(syms)}" if syms else ""
                s += f"  {rel}{sym_str}\n"
            if len(paths) > MAX_FILE_LIST_PER_DIR:
                s += f"  ... and {len(paths) - MAX_FILE_LIST_PER_DIR} more\n"

    s += "\n\nCRITICAL FILE EXCERPTS\n" + "=" * 40 + "\n"
    critical = [
        MOBILE / "lib/screens/record_screen.dart",
        MOBILE / "lib/screens/quick_text_capture_screen.dart",
        MOBILE / "lib/screens/archive_belief_screen.dart",
        MOBILE / "lib/screens/paywall_screen.dart",
        MOBILE / "lib/router/app_router.dart",
        MOBILE / "lib/config/app_config.dart",
        MOBILE / "lib/features/comparison_engine/comparison_engine.dart",
        MOBILE / "lib/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart",
        MOBILE / "lib/features/pro_bridge_visibility/delayed_paywall_proof_store.dart",
        MOBILE / "lib/billing/revenuecat_service.dart",
    ]
    for path in critical:
        if path.is_file():
            total = len(path.read_text(encoding="utf-8", errors="replace").splitlines())
            cap = 100 if total > 250 else min(total, MAX_EXCERPT_LINES)
            s += excerpt(path, max_lines=cap)

    s += """
REGENERATE THIS EXPORT
----------------------
cd apps/voicememory_mobile
python3 tool/generate_app21_export.py

Output folder: ~/Desktop/APP22
Creates exactly 10 UTF-8 plain text files for TextEdit.
Does not modify app source code or commit anything.
"""
    return s


def main() -> None:
    meta = git_meta()
    generators = [
        ("01_PROJECT_OVERVIEW_STATUS_AND_ROADMAP.txt", generate_01),
        ("02_RECORD_CAPTURE_AND_RETURNING_FLOW.txt", generate_02),
        ("03_ARCHIVE_PROOF_COMPARISON_AND_EVIDENCE_FLOW.txt", generate_03),
        ("04_COMPARISON_ENGINE_PROMPT_GUARDRAILS_AND_MODEL_OUTPUT.txt", generate_04),
        ("05_PRO_PAYWALL_REVENUECAT_AND_SUBSCRIPTIONS.txt", generate_05),
        ("06_APP_REVIEW_IOS_SUBMISSION_AND_METADATA.txt", generate_06),
        ("07_FEATURE_MODULES_GATES_AND_PRODUCT_LOGIC.txt", generate_07),
        ("08_UI_SCREEN_MAP_COPY_AND_NAVIGATION.txt", generate_08),
        ("09_TESTS_VALIDATION_KNOWN_FAILURES_AND_LAUNCH_CHECKLIST.txt", generate_09),
        ("10_FULL_DART_CODE_INDEX_AND_KEY_EXCERPTS.txt", generate_10),
    ]
    written: list[Path] = []
    for name, fn in generators:
        content = fn(meta)
        written.append(write_file(name, content))
        print(f"Wrote {written[-1]} ({written[-1].stat().st_size:,} bytes)")

    print("\n=== APP22 EXPORT COMPLETE ===")
    print(f"Folder: {OUT}")
    print(f"Files: {len(written)}")
    for p in written:
        print(f"  {p.name}: {p.stat().st_size:,} bytes")
    print(f"\nBranch: {meta['branch']}")
    print(f"Commit: {meta['commit']}")
    print(f"Git status:\n{meta['status']}")


if __name__ == "__main__":
    main()
