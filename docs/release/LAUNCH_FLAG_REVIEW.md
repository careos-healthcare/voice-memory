# Launch flag review — beta 1

Profile: `config/launch_profiles/beta_1.json`, copied to `apps/mobile/config/launch_profile.json`. `scripts/build-beta.sh` passes the beta file via `--dart-define-from-file`. Dark mode stays off. The reviewed beta turns on encrypted backup, first-save quote-back, onboarding import, gentle reminders, native quick capture, live draft transcript, and trend summaries.

`test/release/launch_profile_test.dart` fails if code references a flag this file does not list, or if the profile names a flag the code does not.

## VOICEMEMORY_ENABLE_PATTERN_EXPLORATION

Shows the pattern exploration card and citation graph on insight surfaces.

Screens: Archive home noticed row, pattern exploration entry.

Tests: `explore_citation_graph_action_test.dart`.

Risks: Exploration copy can read as a claim. Each card still needs a reachable evidence link.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_TREND_PATTERN_SUMMARY

Shows the trend summary card when the archive has enough reflections.

Screens: Archive home noticed row.

Tests: trend summary widget tests that override the flag.

Risks: A short archive can show an empty or over-strong trend. Default off.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_ONBOARDING_IMPORT_FIRST

Shows a second onboarding step that offers the existing notes importer.

Screens: onboarding.

Tests: `first_session_evidence_test.dart`.

Risks: Import runs before the person has seen what a saved moment looks like.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_FIRST_SAVE_QUOTE_BACK

After the first save, quotes the recording back with no interpretation.

Screens: first-save receipt.

Tests: `first_session_evidence_test.dart`.

Risks: A wrong transcript is shown as the person's words. The quote must stay verbatim.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_NATIVE_QUICK_CAPTURE

Turns on widget, Siri, Control Center, Live Activity, and Watch capture links.

Screens: system capture entry points, record.

Tests: `native_quick_capture_test.dart`.

Risks: A deep link can start the microphone outside the in-app record screen.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_ENCRYPTED_BACKUP

Shows passphrase-sealed archive backup to iCloud or a chosen file.

Screens: backup actions and the weekly backup task.

Tests: `encrypted_archive_backup_test.dart`.

Risks: A lost passphrase cannot be recovered. A bad backup could be mistaken for a complete archive.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_GENTLE_REMINDERS

Shows local reminder toggles: daily nudge, on this day, and check back. No server push.

Screens: Settings reminder section.

Tests: `gentle_reminders_test.dart`.

Risks: A reminder can surface an old moment the person did not ask to see that day.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_LIVE_DRAFT_TRANSCRIPT

Shows an on-device partial transcript while recording. It is display-only. The saved transcript still comes from the final pipeline.

Screens: capture recording panel (iOS). Android hides the draft.

Tests: recording feedback tests that the draft is never written onto `JournalEntry.transcript`.

Risks: A partial line can be read as the saved words. It must stay muted and unsaved.

Approved by Chirag / date:

## THOUGHTPRINT_DARK_MODE_READY

Follows the system appearance instead of forcing the light theme.

Screens: app-wide theme.

Tests: dark-mode golden tests.

Risks: Screens that still read light-only colors will be unreadable on a dark surface.

Approved by Chirag / date:

## VOICE_MEMORY_ENABLE_BETA_SURFACES

Master gate for Ask Archive, thematic lenses, live conversation, image evidence, and the coach tier. Each of those also has its own flag.

Screens: Archive search Ask action, record mode toggle, onboarding lens selector.

Tests: `beta_surfaces_feature_gates_test.dart`, `ask_archive_screen_test.dart`.

Risks: Turns on several unfinished surfaces at once. Leave off unless each child flag is also reviewed.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_LIVE_CONVERSATION

Allows Gemini live conversation mode. Still requires the beta-surfaces master flag.

Screens: record mode toggle.

Tests: `recording_mode_test.dart`.

Risks: Sends audio into a live session. Not part of the on-device capture path.

Approved by Chirag / date:

## ENABLE_LIVE_VOICE_CAPTURE

Legacy alias for live conversation. Same surface as `VOICEMEMORY_ENABLE_LIVE_CONVERSATION`.

Screens: record mode toggle.

Tests: `recording_mode_test.dart`.

Risks: An old define name can turn the live path on without the newer name. Keep both false.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_IMAGE_EVIDENCE

Allows camera or gallery attachments as evidence. Still requires the beta-surfaces master flag.

Screens: evidence attachment entry points.

Tests: image-evidence flag tests.

Risks: Photos are a new data type in an archive that otherwise stores words and audio.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_PROFESSIONAL_COACH

Allows professional or coach account routing. Still requires the beta-surfaces master flag.

Screens: account and coach surfaces.

Tests: `professional_coach_feature_flags_test.dart`.

Risks: A coach surface can imply a second person can read the archive.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_CAREGIVER_MODE

Shows caregiver monitoring, grant, and consent screens.

Screens: Settings caregiver access, consent entry.

Tests: `caregiver_feature_flags_test.dart`, caregiver route and session-guard tests.

Risks: Another person can be granted a view of private entries. Server consent is not the public-beta path.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_WATCH_COMPANION

Enables the Apple Watch quick-record companion.

Screens: watch capture, phone connectivity.

Tests: `watch_companion_feature_flags_test.dart`, `watch_connectivity_service_test.dart`.

Risks: Recording can start from the watch without the phone's record screen in front of the person.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_THEORY_TRACKING

Enables theory-tracking surfaces used by archive synthesis.

Screens: theory and synthesis views when those routes are open.

Tests: `archive_synthesis_pack_test.dart`, `archive_quality_validation_test.dart`.

Risks: A theory line can sound more certain than the cited entries support.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_PROVENANCE_RECOVERY

Enables provenance recovery for evidence whose source trail is incomplete.

Screens: evidence and belief-change views that consult provenance.

Tests: provenance recovery flag coverage in the belief-evidence suite.

Risks: Recovered provenance must not invent a quote that was not stored.

Approved by Chirag / date:

## VOICEMEMORY_EXPERIMENT_H_ONBOARDING

Shows the experiment-H onboarding comparison card.

Screens: archive onboarding.

Tests: `chatgpt_vs_evidence_card_test.dart`.

Risks: Experimental onboarding copy is not the reviewed first-run path.

Approved by Chirag / date:

## VOICEMEMORY_ENABLE_CLINICAL_SANDBOX

Requests the clinical-signal sandbox. It stays off unless a dev token and an internal-build define are also set, and it refuses release builds otherwise.

Screens: clinical sandbox only.

Tests: `clinical_sandbox_feature_flags_test.dart`.

Risks: Biomarker-style analysis is out of scope for a public beta. The token is not in this profile.

Approved by Chirag / date:

## VOICEMEMORY_CLINICAL_SANDBOX_INTERNAL_BUILD

Marks a build as an internal clinical build. Does nothing while the clinical sandbox flag is false.

Screens: none on their own.

Tests: `clinical_sandbox_feature_flags_test.dart`.

Risks: Setting this alone must not expose clinical UI. The sandbox still requires its other gates.

Approved by Chirag / date:

## ARCHIVEME_DISABLE_POST_SAVE_ARCHIVE_CARDS

Skips archive and memory cards on the save receipt. This is a kill switch, not a feature. False means the normal receipt still runs.

Screens: post-save receipt.

Tests: post-save stability gate tests.

Risks: Setting it true hides cards the person may be expecting. Leave false.

Approved by Chirag / date:
