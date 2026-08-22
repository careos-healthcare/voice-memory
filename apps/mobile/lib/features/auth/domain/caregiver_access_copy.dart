/// Plain-language copy for caregiver and coach access controls.
///
/// Only two roles are described because only two are ever constructed:
/// `MultiPartyAccessService` produces `MultiPartyAccessRole.caregiver` and
/// `MultiPartyAccessRole.coach`. `observer` has no production writer.
///
/// Copy here may say that *this device* runs a permission check, because it
/// does. `CaregiverSessionGuard` gates the sanitized export, the bulk journal
/// export, the raw journal JSON, the account portability ZIP, the sealed
/// `.archiveme` backup, the manual local-backup share
/// (`LocalBackupRestoreService.exportBackup`), the selected-entry markdown
/// (`SelectedArchiveExport.buildOwnerMarkdown`), every capture write, and both
/// audio playback paths (`PlaybackService.playFile` and
/// `CitationPlaybackLauncher.play`); it denies a caregiver session and denies
/// again when the persona cannot be read.
///
/// Two things it does not cover, and copy must not read as though it did:
///
/// - The selected-entry share sheet
///   (`lib/widgets/export/export_selected_sheet.dart`) still calls the
///   ungated synchronous `SelectedArchiveExport.buildMarkdown`. The gate
///   exists and is tested; the production route does not go through it yet, so
///   what holds that one screen back is still route isolation.
/// - There is no server-side caregiver read API for a check to sit in front
///   of, so someone holding a valid token who does not use this app is
///   unaffected by any of the above. Revocation is the one thing the server
///   does enforce.
///
/// Write the device scope into the sentence rather than leaving it to context.
/// See `docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md`.
abstract final class CaregiverAccessCopy {
  CaregiverAccessCopy._();

  static const screenTitle = 'Caregiver & coach access';

  static const settingsTitle = 'Caregiver & coach access';
  static const settingsSubtitle =
      'See what is shared, review active grants, and revoke access';

  static const controlHeading = 'You stay in control';
  static const controlBody =
      'Sharing is optional. Every grant requires your explicit consent, '
      'can include an expiry date, and can be revoked on this device at '
      'any time.';

  static const canSeeHeading = 'What they can see';
  static const caregiverCanSeeTitle = 'Caregiver';
  static const caregiverCanSeeBody =
      'Read-only summaries built from the categories you approved: how many '
      'moments you have preserved, short labels for recent ones, a timeline '
      'summary, and priority alerts. Each read is logged on this device.';
  static const coachCanSeeTitle = 'Coach';
  static const coachCanSeeBody =
      'Read-only insight summaries of the kinds you approved when you signed '
      'the grant. A coach receives no alerts and cannot change the scope you '
      'chose.';

  static const cannotSeeHeading = 'What the shared view leaves out';
  static const String _sharedViewOmitsRecordings =
      'Full transcripts and audio — a shared view carries counts, short '
      'labels, and summaries, not the recording or its text';
  static const List<String> cannotSeeBullets = [
    _sharedViewOmitsRecordings,
    'Your app lock, device passcode, or account sign-in details',
  ];

  static const scopeNoteHeading = 'Read the scope carefully';
  static const scopeNoteBody =
      'You approve categories of summary, not individual moments: a caregiver '
      'grant for the journal category summarises everything in your journal, '
      'not a selection you pick entry by entry.';

  static const intentHeading = 'Limits this device enforces';
  static const intentBody =
      'On this device, exporting, recording, and playing back your original '
      'audio are blocked by a permission check while a caregiver session is '
      'active, and the check refuses when it cannot tell whose session it is. '
      'That check runs here, not on a server, so it describes what this app '
      'does on this device rather than what someone holding a token can do '
      'somewhere else.';

  static const activeGrantsHeading = 'Active access grants';
  static const emptyGrantsMessage =
      'No active caregiver or coach grants on this device.';
  static const revokeAccessCta = 'Revoke Access';
  static const revokeConfirmTitle = 'Revoke access?';
  static const revokeConfirmBody =
      'This takes effect on this device right away: the grant leaves this list '
      'and this device stops accepting it. A consent token already issued to '
      'them stays valid on the server until its expiry date, so it can keep '
      'working elsewhere until then.';
  static const revokeSuccessSnack = 'Access revoked on this device.';
  static const grantedLabel = 'Granted';
  static const expiresLabel = 'Expires';
  static const roleLabel = 'Role';
  static const currentSessionBadge = 'Active now';

  static const auditTrailLinkTitle = 'Consent audit trail';
  static const auditTrailLinkSubtitle =
      'Past and revoked grants, plus the local record of what was read';
}
