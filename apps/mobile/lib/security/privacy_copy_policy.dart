/// Canonical privacy promises and guards against overclaiming in consumer copy.
abstract class PrivacyCopyPolicy {
  PrivacyCopyPolicy._();

  // ——— Allowed promise constants ———

  static const String privateByDefault = 'Private by default';

  // `nothingSentUnlessChosen` — "Nothing is sent unless you choose cloud,
  // sync, or transcription." — was retired here. It made the same promise as
  // [nothingSentUnlessFeatureChosen] in different words, no app code read it,
  // and two constants for one promise is how a correction reaches one surface
  // and not the other.

  static const String exportDeleteAnytime =
      'You can export or delete your local archive at any time.';

  static const String deleteLocalArchive = 'Delete local archive';

  static const String transcriptionAnalysisWhenUsed =
      'Some features send audio or text for transcription or analysis when you use them.';

  static const String journalEncryptedAtRest =
      'Your journal file on this device is encrypted.';

  /// Compact label for the muted encryption-at-rest badge.
  ///
  /// Scoped to the journal on purpose. Two stores hold user content and only
  /// one of them is encrypted on every platform:
  ///
  /// * journal entries — `JournalStore` writes an AES-GCM envelope through
  ///   `EncryptedJsonFileStore` (`AesGcm.with256bits()`), and
  ///   `AppServices` passes `encryptAtRest: true` for every run that is not
  ///   `flutter test`, so this half is not platform-gated;
  /// * the index that searches them — `archiveme.db` opens through SQLCipher,
  ///   but `SqliteDatabaseInitializer.encryptionEnabled` ands the runtime flag
  ///   with `Platform.isIOS || Platform.isAndroid`, so this half is mobile-only
  ///   and [encryptionBaselineDetail] has to say so.
  ///
  /// "Journal" rather than "your data": preferences and archive metadata stay
  /// plain JSON, as `privacy_data_controls_copy.dart` already admits.
  static const String encryptedAtRestScoped = 'Journal encrypted at rest';

  /// The supporting detail under [encryptedAtRestScoped].
  ///
  /// States the platform scope, the key handling, and what is *not* covered,
  /// so the badge cannot be read as covering everything on disk. Both keys are
  /// 32 bytes held by `SecureStorageService`, which configures
  /// `AndroidOptions(encryptedSharedPreferences: true)` and
  /// `IOSOptions(accessibility: KeychainAccessibility.first_unlock)`; nothing
  /// writes either key to a network call.
  static const String encryptionBaselineDetail =
      'The journal file is encrypted with AES-256 on this device. '
      'On iOS and Android the database that indexes it is encrypted as well. '
      'Keys stay in secure storage on this device and are never transmitted. '
      'Preferences and archive metadata are not covered.';

  static const String lockArchiveMe = 'Protect this archive';

  /// Calm first-run / legal disclaimer — no encryption or therapy claims.
  static const String personalNotMedicalDisclaimer =
      'Your recordings and reflections are personal. Some data may be stored '
      'on this device. ArchiveMe is not therapy, medical advice, or emergency '
      'support.';

  /// Shorter variant for compact trust rows — still requires an explicit choice.
  static const String nothingSentUnlessFeatureChosen =
      'Nothing is sent unless you choose a feature that needs it.';

  // ——— Canonical promises ———
  //
  // Absorbed from the former `lib/security/privacy_contract.dart`, which was
  // reachable only from its own tests and whose encryption promise was a
  // second assembly of [encryptedAtRestScoped] and [encryptionBaselineDetail].
  // These say what the app promises about user data; behavioural code has to
  // enforce them rather than contradict them.

  /// The scoped encryption-at-rest baseline, as one statement.
  static const String journalEncryptedAtRestPromise =
      '$encryptedAtRestScoped. $encryptionBaselineDetail';

  /// Journal content is not uploaded unless the user uses a feature that
  /// requires remote transcription, sync, or analysis and has granted consent.
  static const String journalNotUploadedWithoutConsent =
      'Journal content is not sent to our servers unless you use cloud sync, '
      'transcription, or another feature that requires it and you have agreed.';

  /// Each signed-in account has physically separate local storage; switching
  /// accounts never reads or writes another account's namespace.
  static const String accountStorageIsolated =
      'Each account has its own local storage on this device; other accounts '
      'on the same device cannot access your reflections.';

  /// Deleting an account removes server-side data; the local copy is a
  /// separate explicit step on the device.
  static const String deletionServerThenLocal =
      'Account deletion removes your server account and synced data first; '
      "deleting this device's local copy is a separate choice afterward.";

  /// Analytics and trial metrics must not include journal body text.
  static const String analyticsExcludeJournalBody =
      'Product analytics must not include journal body text or raw transcripts.';

  static const List<String> canonicalPromises = [
    journalEncryptedAtRestPromise,
    journalNotUploadedWithoutConsent,
    accountStorageIsolated,
    deletionServerThenLocal,
    analyticsExcludeJournalBody,
  ];

  // ——— Consumer privacy copy sources ———

  /// This file declares the banned vocabulary, so scanning it would only ever
  /// report its own rule table.
  static const String policySelfPath = 'lib/security/privacy_copy_policy.dart';

  /// Path fragments that mark a Dart file as a user-facing privacy, trust, or
  /// consent surface even when it is not a `*_copy.dart` constants class.
  static final RegExp _surfacePathPattern = RegExp(
    'privacy|trust|consent|security|onboarding',
    caseSensitive: false,
  );

  /// Whether [path] holds copy a user can read on a privacy or trust surface.
  ///
  /// This predicate — not a hand-maintained list — decides what gets scanned.
  /// A caller walks `lib/` and asks about every Dart file it finds, so a new
  /// copy file is covered the moment it lands. Widen the predicate rather than
  /// enumerating files; [consumerPrivacySources] exists only for the handful
  /// of surfaces whose path says nothing about what they contain.
  static bool isConsumerPrivacySource(String path) {
    final normalized = path.replaceAll(r'\', '/');
    if (!normalized.endsWith('.dart')) return false;
    if (!normalized.startsWith('lib/')) return false;
    if (normalized == policySelfPath) return false;
    if (normalized.endsWith('_copy.dart')) return true;
    if (consumerPrivacySources.contains(normalized)) return true;
    return _surfacePathPattern.hasMatch(normalized);
  }

  /// Surfaces that discovery cannot infer from the path, listed explicitly.
  ///
  /// Not the scan set — discovery is. A guard test asserts every entry here
  /// still exists, so this list fails loudly instead of rotting the way the
  /// previous hand-maintained scan set did.
  static const List<String> consumerPrivacySources = [
    'lib/security/archive_privacy_controls_copy.dart',
    'lib/security/account_privacy_controls_copy.dart',
    'lib/security/security_settings_copy.dart',
    'lib/features/trust/pro_trust_copy.dart',
    'lib/record/record_screen_framing_copy.dart',
    'lib/auth/auth_trigger_rules.dart',
    'lib/screens/privacy_screen.dart',
    'lib/widgets/security/archive_data_flow_sheet.dart',
    'lib/widgets/security/archive_privacy_controls_card.dart',
    'lib/widgets/account/account_privacy_controls_section.dart',
    'lib/features/privacy/privacy_security_trust_copy.dart',
    'lib/widgets/settings/privacy_security_trust_section.dart',
    'lib/features/trust/terms_screen_copy.dart',
    'lib/features/onboarding/first_user_experience_copy.dart',
    'lib/features/onboarding/ui/remote_processing_consent_copy.dart',
    'lib/features/settings/ui/on_device_architecture_copy.dart',
    'lib/features/settings/ui/on_device_architecture_section.dart',
  ];

  /// Verbs for moving a payload off this device or committing it to disk.
  ///
  /// `stays` is deliberately absent: "The database stays encrypted" describes a
  /// state rather than an act, and it is a claim the desktop build contradicts.
  static const String _custodyVerbs =
      'upload|uploads|uploaded|uploading|'
      r'back(?:s|ed|ing)?\s+up|'
      'sync|syncs|synced|syncing|'
      'store|stores|storing|stored|'
      'send|sends|sending|sent';

  /// The stores `PrivateStorageAudit` records as `encrypted: false`.
  ///
  /// `VoiceRecordings` is `temp_file` / `encrypted: false` — `vm_rec_*.m4a`
  /// plaintext under the system temp directory — so no copy may call recorded
  /// audio encrypted, whatever verb it uses. This is the veto that keeps
  /// [_custodyVerbNearEncryption] from licensing a false claim: "Uploading your
  /// encrypted audio" and "Uploading encrypted changes…" are the same sentence
  /// shape, and only this list knows that one of the two subjects is plaintext.
  ///
  /// `prefs` and `metadata` are deliberately absent even though they are also
  /// plaintext. Every honest string that names them names them *as* plaintext
  /// ("Archive metadata and prefs remain in plaintext JSON"), so vetoing on the
  /// noun would report the disclosure instead of the claim.
  static const String _plaintextStoreSubjects =
      r'audio|recording|recordings|voice\s+note|voice\s+notes|m4a|temp\s+file';

  /// An encryption claim whose subject is a store known to be plaintext.
  ///
  /// Adjacency, not co-occurrence: `private_storage_audit.dart` says "entries
  /// in encrypted journal + localAudioPath (audio plaintext)", where the
  /// encrypted thing is the journal and the audio is named as plaintext in the
  /// same breath. That must keep clearing, so only `encrypted <subject>` and
  /// `<subject> is encrypted` count.
  static final RegExp _plaintextSubjectEncryptionClaim = RegExp(
    r'\bencrypt(?:ed|ing)?\s+(?:your\s+|the\s+|this\s+|my\s+|their\s+)?'
    '(?:$_plaintextStoreSubjects)'
    r'\b'
    '|(?:$_plaintextStoreSubjects)'
    r'\s+(?:\w+\s+)?(?:is|are|was|were|gets?|stays?|remains?)\s+encrypted\b',
    caseSensitive: false,
  );

  /// A custody verb sitting in the same clause as an encryption word.
  ///
  /// The former entries matched fixed word orders — `encrypted backup`,
  /// `encrypted sync` — so four accurate strings failed for their phrasing
  /// rather than their content: `sync_status_copy.dart`'s "Uploading encrypted
  /// changes…" (the outbox drains `SyncBlobPushDto.encrypted`, an
  /// `EncryptedPayloadDto`) and "Backing up encrypted vault…"
  /// (`EncryptedSqliteVaultSyncPipeline.uploadVault` seals the SQLite bytes with
  /// AES-256-GCM before the iCloud transport sees them), and
  /// `privacy_data_controls_copy.dart`'s "ArchiveMe stores your journal file
  /// encrypted on this device".
  ///
  /// This recognises the shape instead. It is safe only because
  /// [_plaintextSubjectEncryptionClaim] is checked first and cannot be
  /// overridden — on its own this pattern clears "Uploading your encrypted
  /// audio" too, which is exactly the false claim the veto exists to keep.
  static final RegExp _custodyVerbNearEncryption = RegExp(
    '(?:$_custodyVerbs)'
    r'\b[^.;:!?—]{0,40}?\bencrypt(?:ed|ing|ion)?\b'
    '|'
    r'\bencrypt(?:ed|ing|ion)?\b[^.;:!?—]{0,40}?\b(?:$_custodyVerbs)\b',
    caseSensitive: false,
  );

  static final List<RegExp> _allowedEncryptedContexts = [
    RegExp('optional encrypted backup', caseSensitive: false),
    RegExp(r'encrypt(?:ed)?\s+(?:a\s+)?backup', caseSensitive: false),
    RegExp('encrypted before it is', caseSensitive: false),
    RegExp('encrypted sync', caseSensitive: false),
    RegExp('journal file on this device is encrypted', caseSensitive: false),
    // The approved scoped baseline, kept deliberately narrow. Anchoring the
    // label means only the exact string clears; a bare "Encrypted at Rest" or
    // "your data is encrypted at rest" still reports, which is the point.
    RegExp(r'^Journal encrypted at rest$'),
    RegExp(
      'journal file is encrypted with AES-256 on this device',
      caseSensitive: false,
    ),
    // `JournalStore` is `encrypted_json_file` / `encrypted: true`, so naming the
    // journal as the encrypted thing is accurate with or without a custody verb.
    // This is what clears `private_storage_audit.dart`'s draft note, which has
    // no verb for the verb rule below to find.
    RegExp(r'encrypted\s+journal', caseSensitive: false),
    _custodyVerbNearEncryption,
  ];

  // ——— Absolute and quantified privacy claims ———
  //
  // The trigger used to be the three literal phrases `never sent`,
  // `never leaves`, and `nothing ever leaves`, which matched wording rather
  // than the shape of a promise. Both of these cleared it:
  //
  //   'All AI processing happens 100% on your device hardware'
  //   'zero data is ever sent to OpenAI, Anthropic, or external cloud servers.'
  //
  // What makes a privacy claim unsafe is that it admits no exception, not
  // which verb carries it. So the rules below look for an absolute qualifier
  // sitting in the same clause as a privacy subject, with no condition
  // attached — and treat a deliberately scoped promise as the safe form.

  /// Ways of saying user content moves off this device.
  static const String _egressVerbs =
      'sent|send|sends|sending|'
      'shared|share|shares|sharing|'
      'uploaded|upload|uploads|uploading|'
      'transmitted|transmit|transmits|transmitting|'
      'transferred|transfer|transfers|'
      'leaves|leave|leaving';

  /// An unconditional denial that content ever moves off the device.
  ///
  /// Kept as its own rule, with its own narrow excuse, because it is the one
  /// claim shape that is unsafe even when a condition is nearby: "never
  /// uploaded when you are offline" is still a promise nothing can keep.
  static final RegExp _neverSentPattern = RegExp(
    r'\bnever\s+(?:be\s+|ever\s+|get\s+|gets\s+)?(?:' '$_egressVerbs' r')\b'
    r'|\bnothing\s+(?:ever\s+)?leaves\b',
    caseSensitive: false,
  );

  /// Excuses for [_neverSentPattern] — deliberately only the two conditions
  /// that name the user's own action, so a passive "when offline" cannot
  /// launder the claim.
  static final RegExp _neverSentExcusePattern = RegExp(
    r'unless you (?:choose|turn|enable|opt)'
    r'|until you (?:choose|turn|enable|opt)',
    caseSensitive: false,
  );

  /// Qualifiers that make a statement admit no exception.
  static final RegExp _absoluteQualifierPattern = RegExp(
    r'\b100\s*(?:%|percent)'
    r'|\bzero\b'
    r'|\bnever\b'
    r'|\balways\b'
    r'|\bnothing\b'
    r'|\bnone\b'
    r'|\bno\s+one\b|\bno-one\b|\bnobody\b'
    r'|\bentirely\b|\bcompletely\b|\btotally\b|\bwholly\b|\babsolutely\b'
    r'|\bpurely\b|\bsolely\b|\bexclusively\b'
    r'|\bonly\s+ever\b|\bever\s+only\b'
    r'|\bat\s+all\s+times\b|\bunder\s+no\s+circumstances\b'
    r'|\bguarantee[ds]?\b'
    r'|\bevery\s+single\b'
    r'|\ball\s+(?:of\s+)?your\b',
    caseSensitive: false,
  );

  /// What a claim has to be *about* for an absolute qualifier to matter.
  ///
  /// An absolute qualifier alone says nothing — "always with your own words
  /// cited behind them" is not a privacy promise. The qualifier, this subject,
  /// and [_exceptionBearingActPattern] must all share a clause.
  ///
  /// These are the nouns that make a claim range over the *product* rather
  /// than the screen it is written on: the content itself, somewhere off this
  /// device, someone other than the user, or where processing runs. Naming one
  /// of them is what turns "nothing is uploaded" into a promise a reader
  /// cannot check by looking at the screen in front of them.
  ///
  /// Bare storage and archive nouns like "saved" and "moments" are absent
  /// because they made every empty state a privacy claim — "Nothing saved
  /// yet", "visible at zero entries", "nothing in your saved entries matches
  /// it" are counts and UI states, not promises.
  static final RegExp _productWideSubjectPattern = RegExp(
    r'\bdata\b|\binformation\b|\bcontents?\s+of\b'
    r'|\baudio\b|\brecording[s]?\b|\btranscript[s]?\b'
    r'|\bentry\b|\bentries\b|\bjournal\b|\barchive\b|\bkeys?\b'
    r'|\bdevice\b|\bon-device\b|\boffline\b'
    r'|\bserver[s]?\b|\bcloud\b|\bremote\b|\binternet\b|\bnetwork\b'
    r'|\bopenai\b|\banthropic\b|\bthird[- ]part(?:y|ies)\b'
    r'|\bno\s+one\b|\bno-one\b|\bnobody\b|\banyone\b|\banybody\b',
    caseSensitive: false,
  );

  /// The acts this product actually performs, and so the only ones an
  /// unconditional denial can be wrong about.
  ///
  /// Everything ArchiveMe does that a privacy claim could misdescribe is one
  /// of four things: moving content off the device, choosing where it is
  /// stored, choosing where it is processed, or letting someone other than the
  /// user read it. Each has an exception — sync, transcription, analysis,
  /// caregiver access — that a user turns on, which is exactly why a claim
  /// covering one of them has to name its condition.
  ///
  /// `export` and `include` are deliberately absent. Both are user-initiated
  /// by construction — an export happens because a button was pressed, and
  /// what a share card includes is fixed by the card — so "raw transcripts are
  /// never exported" and "share-safe proof never includes raw entries" have no
  /// exception to admit. The hyphen-aware boundaries stop compounds like
  /// "Share-safe" from reading as the verb "share".
  static final RegExp _exceptionBearingActPattern = RegExp(
    '(?<![\\w-])(?:$_egressVerbs)(?![\\w-])'
    r'|(?<![\w-])(?:stored?|stores|storing|stays?|stayed|staying)(?![\w-])'
    r'|(?<![\w-])process(?:ed|es|ing)?(?![\w-])'
    r'|(?<![\w-])(?:read|reads|sees?|seen|views?|viewed'
    r'|access|accesses|accessed)(?![\w-])',
    caseSensitive: false,
  );

  /// Whether [text] is a privacy or trust statement rather than product copy.
  ///
  /// The duplication gate uses this to stay on its subject. The copy scan
  /// walks nearly every `*_copy.dart` in the app, and two screens sharing
  /// "View pattern" is a style question, not a claim stated twice — whereas
  /// two screens spelling out where data goes is two places a correction has
  /// to land. The vocabulary is deliberately different from
  /// [_productWideSubjectPattern], which has to carry "no one" and "anyone" to
  /// read a sentence like "no one can view your transcripts".
  static bool isTrustCopy(String text) => _trustVocabularyPattern.hasMatch(text);

  static final RegExp _trustVocabularyPattern = RegExp(
    r'\bprivacy\b|\bprivate\b|\bsecure\b|\bsecurity\b|\bencrypt(?:ed|ion|s)?\b'
    r'|\bon-device\b|\boffline\b|\bcloud\b|\bserver[s]?\b|\bremote\b'
    r'|\bupload(?:ed|s|ing)?\b|\btransmit(?:ted|s|ting)?\b|\bciphertext\b'
    r'|\bat rest\b|\bconsent\b|\bcaregiver\b|\bcoach access\b'
    r'|\bbiometric[s]?\b|\bface id\b|\btouch id\b|\bpasscode\b|\bunlock\b'
    r'|\b(?:delete|wipe|erase|clear)\b[^.]{0,40}\barchive\b'
    r'|\barchive\b[^.]{0,40}\b(?:deleted|wiped|erased|cleared)\b',
    caseSensitive: false,
  );

  /// Conditions that turn an absolute statement into a scoped one.
  ///
  /// A scoped promise is the shape this product is allowed to make: it names
  /// the trigger, so a user can check it. "Nothing is sent unless you choose a
  /// feature that needs it" is safe for exactly the reason "nothing is sent"
  /// is not.
  /// Naming the control that changes a promise is itself a scope, and the one
  /// this product asks users to check. "Nothing is sent for new moments, and
  /// the switch lives in Settings → Privacy" tells a reader where to go and
  /// disprove it; "nothing is sent" does not.
  static final RegExp _claimScopePattern = RegExp(
    r'\bunless\b|\buntil\b|\bwhen(?:ever)?\b|\bwhile\b|\bif\b'
    r'|\bby default\b'
    r'|\bwithout your\b|\bwithout you\b|\bwithout explicit\b'
    r'|\brequires? your\b|\bwith your\b'
    r'|\byou choose\b|\byou turn\b|\byou enable\b|\byou opt\b|\bopt[- ]in\b'
    r'|\bswitch\b|\btoggle\b|\bsettings?\b'
    r'|\bturn(?:s|ed|ing)?\s+(?:it\s+|this\s+|that\s+)?(?:on|off)\b',
    caseSensitive: false,
  );

  /// Empty states, not promises. "Nothing saved yet" and "Nothing to export
  /// yet" are counts of what the user has done so far.
  static final RegExp _emptyStatePattern = RegExp(
    r'\b(?:nothing|none|no)\b[^.;:!?—]*\byet\b',
    caseSensitive: false,
  );

  /// Cues that make an absolute word a disavowal, a prohibition, or an
  /// internal rule rather than a promise to a user.
  ///
  /// Read across the whole literal, not the clause: a string that opens
  /// "Blocked unless sync proven:" or "Avoid …" is a prohibition list for its
  /// full length, the same way [_bannedVocabularyDeclaration] treats a guard
  /// collection. A rule forbidding a claim must not be read as making it.
  static final RegExp _claimDisavowalCue = RegExp(
    r'\b(?:rather\s+than|instead\s+of|unlike|versus|vs\.?)\b'
    r'|\b(?:avoid|avoids|ban|bans|banned|block|blocks|blocked|forbid|forbids|'
    r'forbidden|prohibit|prohibits|reject|rejects|risky)\b'
    r'|\b(?:never|do\s+not|don[\u0027\u2019]t)\s+say\b'
    r'|\bno\s+(?:[\w-]+\s+){0,5}(?:promise|claim|claims|framing|language|copy)'
    r'\b',
    caseSensitive: false,
  );

  /// Approved unconditional claims, anchored to their exact wording.
  ///
  /// An absolute claim is not automatically false — it is automatically
  /// something that has to be checked against code. Each entry here has been,
  /// and the comment above it names the evidence. Anchoring means a reworded
  /// variant reports again instead of inheriting the approval.
  /// Whole sentences, not fragments, so approving one cannot approve a
  /// neighbouring claim that happens to share a literal.
  static final List<RegExp> _approvedAbsoluteClaims = [
    // `SecureStorageService` holds both 32-byte keys in the Keychain and in
    // `EncryptedSharedPreferences`; no call site puts either on the wire.
    RegExp('Keys stay in secure storage on this device and are never '
        'transmitted'),
  ];

  /// Whether [line] is an absolute privacy claim with no condition attached.
  ///
  /// Clause-scoped on purpose: a qualifier in one sentence must not be excused
  /// by a condition in the next, and a condition in one sentence must not be
  /// borrowed by an absolute claim in the next.
  ///
  /// A clause has to carry three things before it counts as a claim at all —
  /// an absolute qualifier, a subject that ranges over the product
  /// ([_productWideSubjectPattern]), and an act the product actually performs
  /// ([_exceptionBearingActPattern]). Requiring all three is what separates
  /// "zero data is ever sent to OpenAI, Anthropic, or external cloud servers"
  /// from "Nothing is uploaded" on a screen that makes no network call. The
  /// first denies an exception this app has and a reader cannot check; the
  /// second is bounded to the surface it appears on, true there, and would be
  /// made *less* accurate by bolting a condition onto it.
  static bool isUnscopedAbsoluteClaim(String line) {
    if (_claimDisavowalCue.hasMatch(line)) return false;
    for (final match in _absoluteQualifierPattern.allMatches(line)) {
      final clause = _clauseAround(line, match.start);
      if (!_productWideSubjectPattern.hasMatch(clause)) continue;
      if (!_exceptionBearingActPattern.hasMatch(clause)) continue;
      if (_claimScopePattern.hasMatch(clause)) continue;
      if (_emptyStatePattern.hasMatch(clause)) continue;
      if (_approvedAbsoluteClaims.any((p) => p.hasMatch(clause))) continue;
      return true;
    }
    return false;
  }

  /// Whether [line] is a reviewed absolute claim or is not a claim at all.
  static bool _isDisavowedOrApproved(String line) =>
      _claimDisavowalCue.hasMatch(line) ||
      _approvedAbsoluteClaims.any((pattern) => pattern.hasMatch(line));

  /// The sentence-or-clause of [line] that contains [index].
  static String _clauseAround(String line, int index) {
    final before = line.substring(0, index);
    final boundary = before.lastIndexOf(_clauseBoundary);
    final start = boundary >= 0 ? boundary + 1 : 0;
    final rest = line.substring(index);
    final endOffset = rest.indexOf(_clauseBoundary);
    final end = endOffset >= 0 ? index + endOffset : line.length;
    return line.substring(start, end);
  }

  static final RegExp _encryptPattern = RegExp(
    'encrypt',
    caseSensitive: false,
  );

  // ——— Encryption scope ———
  //
  // Promoted from `unscopedEncryptionViolations` in
  // `test/features/onboarding/ui/on_device_hero_copy_test.dart`, where it
  // guarded one screen. The claims it rejects are wrong wherever they appear.

  /// Subjects too broad to be true of anything this app writes to disk.
  ///
  /// Preferences and archive metadata are plain JSON on every platform, as
  /// `privacy_data_controls_copy.dart` already admits, so "your data" and
  /// "journal content" sweep in more than the encrypted journal *file*.
  static const List<String> _overbroadEncryptionSubjects = [
    'your data is encrypted',
    'your data are encrypted',
    'all your data',
    'all data is encrypted',
    'everything is encrypted',
    'all journal data is encrypted',
    'journal content is encrypted',
    'journal content on this device is encrypted',
    'journal data is encrypted',
  ];

  /// Words that mean the SQLCipher half of storage.
  ///
  /// `SqliteDatabaseInitializer.encryptionEnabled` ands the runtime flag with
  /// `Platform.isIOS || Platform.isAndroid`, so a claim about the database has
  /// to name both platforms or it is false on a desktop build.
  static const List<String> _databaseSubjects = [
    'database',
    'vault',
    'sqlite',
    'sqlcipher',
  ];

  static final RegExp _iosWord = RegExp(r'\bios\b');

  /// Encryption claims that overstate their subject or drop platform scope.
  static List<String> unscopedEncryptionViolations(String text) {
    final lower = text.toLowerCase();
    final violations = <String>[
      for (final subject in _overbroadEncryptionSubjects)
        if (lower.contains(subject)) subject,
    ];

    final namesBothPlatforms =
        lower.contains('android') && _iosWord.hasMatch(lower);
    if (lower.contains('encrypt') &&
        _databaseSubjects.any(lower.contains) &&
        !namesBothPlatforms) {
      violations.add('database encryption claim without iOS/Android scope');
    }

    final assertsAtRest =
        lower.contains('encrypted at rest') ||
        lower.contains('encryption at rest');
    if (assertsAtRest && !lower.contains('journal')) {
      violations.add('unscoped "encrypted at rest"');
    }
    return violations;
  }

  /// Cloud work described as something the app decides rather than something
  /// the user asked for.
  ///
  /// Nothing sends on its own: `CaptureProofAnalyzer.isPurposeGranted` returns
  /// false while `OnDeviceProcessingStore.enabled` is set — the default — and
  /// otherwise defers to `RemoteProcessingConsentStore`, whose unset state is
  /// `consented: false`. Copy that pairs a remote word with an automatic word
  /// tells a user who declined that their data went anyway.
  static const List<String> _remoteWords = ['cloud', 'server', 'remote'];

  static const List<String> _unpromptedWords = [
    'fallback',
    'falls back',
    'automatic',
    'automatically',
    'on its own',
    'behind the scenes',
  ];

  static List<String> unpromptedRemoteProcessingViolations(String text) {
    final lower = text.toLowerCase();
    if (!_remoteWords.any(lower.contains)) return const [];
    return [
      for (final word in _unpromptedWords)
        if (lower.contains(word)) 'remote work described as "$word"',
    ];
  }

  /// Every claim-level contradiction in [text] — the repo-wide form of the
  /// two guards above.
  static List<String> contradictoryClaimViolations(String text) => [
    ...unscopedEncryptionViolations(text),
    ...unpromptedRemoteProcessingViolations(text),
  ];

  static final RegExp _anonymousPattern = RegExp(
    r'\banonymous\b',
    caseSensitive: false,
  );

  static const List<String> globalBannedPhrases = [
    'therapy',
    'diagnosis',
    'medical',
    'treatment',
    'mental health score',
    'wellbeing score',
    'clinical score',
    'life score',
    'archiveme knows',
    'fake stats',
    'testimonial',
    'everything stays on device',
    'fully encrypted archive',
    '100% secure',
    'unhackable',
    'voice memory',
    'voicememory',
    'ai',
    'artificial intelligence',
    'diagnose',
    'disorder',
    'therapist',
  ];

  static const List<String> _privacySuperlativePhrases = [
    '100% safe',
    'military grade',
    'military-grade',
    'unbreakable',
    'impossible to access',
    'nothing ever leaves your device',
    'delete from every server',
    'all journal data is encrypted',
    'your journal is encrypted',
    'entries are encrypted',
  ];

  /// Returns human-readable violation reasons for a user-visible string literal.
  static List<String> violationsInLiteral(String line) {
    if (line.isEmpty || line.contains(r'${')) return const [];

    final lower = line.toLowerCase();
    final violations = <String>[];

    if (_neverSentPattern.hasMatch(line) &&
        !_neverSentExcusePattern.hasMatch(line) &&
        !_isDisavowedOrApproved(line)) {
      violations.add(
        'overbroad "never sent/leaves" without "unless you choose"',
      );
    }

    if (isUnscopedAbsoluteClaim(line)) {
      violations.add('absolute privacy claim with no stated condition');
    }

    for (final phrase in globalBannedPhrases) {
      final unexcused = _bannedPhraseOccurrences(lower, phrase).any(
        (index) => !_isAllowedBannedPhraseContext(lower, phrase, index),
      );
      if (unexcused) violations.add(phrase);
    }

    for (final phrase in _privacySuperlativePhrases) {
      if (lower.contains(phrase)) {
        violations.add('banned phrase "$phrase"');
      }
    }

    if (_anonymousPattern.hasMatch(line)) {
      violations.add('anonymous claim (not a supported product promise)');
    }

    if (_encryptPattern.hasMatch(line)) {
      // Checked before the allowlist, and not as one of its entries: a claim
      // that calls a plaintext store encrypted must not be rescuable by also
      // matching an approved context.
      if (_plaintextSubjectEncryptionClaim.hasMatch(line)) {
        violations.add(
          'encryption claim about a store PrivateStorageAudit records as '
          'plaintext',
        );
      } else if (!_allowedEncryptedContexts.any((p) => p.hasMatch(line))) {
        violations.add('encryption claim without supported backup/sync context');
      }
    }

    return violations;
  }

  static final RegExp _aiWordPattern = RegExp(r'\bai\b', caseSensitive: false);

  /// Start offsets of every occurrence of [phrase] in [lower].
  ///
  /// Positions, not a bool, because whether a banned word is a claim depends
  /// on the words immediately before *that* occurrence. A literal offends if
  /// any one occurrence is unexcused.
  static List<int> _bannedPhraseOccurrences(String lower, String phrase) {
    if (phrase == 'ai') {
      return _aiWordPattern.allMatches(lower).map((m) => m.start).toList();
    }
    final occurrences = <int>[];
    var index = lower.indexOf(phrase);
    while (index >= 0) {
      occurrences.add(index);
      index = lower.indexOf(phrase, index + 1);
    }
    return occurrences;
  }

  static bool _isAllowedBannedPhraseContext(
    String lower,
    String phrase,
    int index,
  ) {
    if (_isNegatedOccurrence(lower, index)) return true;
    switch (phrase) {
      case 'therapy':
        return lower.contains('not therapy');
      case 'medical':
        return lower.contains('not medical') ||
            lower.contains('medical advice');
      case 'treatment':
        return lower.contains('not treatment');
      case 'diagnosis':
      case 'diagnose':
        return lower.contains('not diagnos');
      default:
        return false;
    }
  }

  /// How far before a banned phrase a negating cue still governs it.
  ///
  /// Wide enough for "does not make medical, therapy, or diagnostic claims",
  /// short enough that an unrelated earlier "not" cannot excuse a real claim.
  static const int _negationWindow = 48;

  /// Where a negating cue stops carrying. Commas are deliberately absent:
  /// "no medical claims, no therapist-ready claims" is one prohibition list.
  static final RegExp _clauseBoundary = RegExp('[.;:!?—]');

  /// Cues that make what follows a rejection or a comparison rather than a
  /// promise — "No medical claims", "not a diagnosis", "Compare against Chat
  /// AI". A guard that forbids a word must not be read as claiming it.
  static final RegExp _negationCue = RegExp(
    r'\b(?:no|not|never|nor|without|nothing)\b'
    r'|\b(?:is|are|was|were|do|does|did|can|could|will|would|has|have)'
    r"n['’]t\b"
    r'|\b(?:compare|compares|compared|comparison)\s+(?:against|to|with)\b'
    r'|\b(?:instead\s+of|rather\s+than|unlike|versus|vs\.?)\b',
    caseSensitive: false,
  );

  /// Whether the banned phrase at [index] sits inside a negating or
  /// contrastive clause.
  ///
  /// Only text back to the nearest clause boundary counts, so "This is not
  /// advice. Diagnosis follows." keeps reporting the second sentence.
  static bool _isNegatedOccurrence(String lower, int index) {
    final start = index < _negationWindow ? 0 : index - _negationWindow;
    var prefix = lower.substring(start, index);
    final boundary = prefix.lastIndexOf(_clauseBoundary);
    if (boundary >= 0) prefix = prefix.substring(boundary + 1);
    return _negationCue.hasMatch(prefix);
  }

  /// Declarations whose contents are prohibitions, not promises — a guard
  /// listing `'therapy'` as forbidden must not be read as claiming therapy.
  static final RegExp _bannedVocabularyDeclaration = RegExp(
    r'\b(banned|forbidden)\w*\b',
    caseSensitive: false,
  );

  static bool _allowlistedLine(String path, String line) {
    if (line.trim().startsWith('import ')) return true;
    if (line.trim().startsWith('//')) return true;
    if (line.contains('package:voicememory_mobile')) return true;
    if (line.contains('PrivacyCopyPolicy.')) return true;
    return _bannedVocabularyDeclaration.hasMatch(line);
  }

  /// Whether [line] opens a multi-line banned-vocabulary collection.
  ///
  /// Without this the declaration line is skipped but its entries are not, so
  /// every guard list in the codebase reports itself once the scan is widened
  /// past hand-picked files.
  static bool _opensBannedVocabularyBlock(String line) {
    if (!_bannedVocabularyDeclaration.hasMatch(line)) return false;
    final opens = line.contains('[') || line.contains('{');
    final closes = line.contains(']') || line.contains('}');
    return opens && !closes;
  }

  static final RegExp _identifierCharacters = RegExp(r'^[A-Za-z0-9_./:%+-]+$');
  static final RegExp _camelCaseBoundary = RegExp('[a-z][A-Z]');

  /// Whether [value] is a machine token — a widget key, preference key, event
  /// name, or path fragment — rather than words a user reads.
  ///
  /// Widening the scan to whole screens pulls in literals like
  /// `encryption_status_card`, which carry no promise. A single plain word can
  /// still be a real label ("Diagnosis"), so only snake_case, dotted, pathed,
  /// or camelCase tokens are treated as machine identifiers.
  static bool isMachineIdentifierLiteral(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.contains(' ')) return false;
    if (!_identifierCharacters.hasMatch(trimmed)) return false;
    return trimmed.contains('_') ||
        trimmed.contains('.') ||
        trimmed.contains('/') ||
        _camelCaseBoundary.hasMatch(trimmed);
  }

  static final RegExp _literalPattern = RegExp("'([^']*)'");

  /// A line holding one single-quoted literal and nothing else.
  ///
  /// The optional `;` catches the last line of a declaration. A trailing comma
  /// is deliberately not allowed, so list entries are never treated as a
  /// continuation of each other.
  static final RegExp _wholeLineLiteral = RegExp(r"^\s*'([^']*)'\s*;?\s*$");

  /// Rejoins the physical lines of an implicit string concatenation.
  ///
  /// Adjacent literals are one string at runtime, and scanning them a line at
  /// a time hides whichever half carries the condition. That is how
  ///
  ///     'Off — new moments are saved on this device only. Nothing is sent '
  ///     'for transcription or reflection until you turn this on.'
  ///
  /// reads as an unconditional "Nothing is sent": the scope cue is on the
  /// other line. A chain that interpolates is left split, so this cannot
  /// change what the `${` skip already covers, and a chain containing an
  /// allowlisted line is left split so the allowlist keeps meaning one line.
  static List<String> joinAdjacentLiterals(String path, List<String> lines) {
    final joined = <String>[];
    var index = 0;

    while (index < lines.length) {
      var end = index;
      while (end < lines.length && _wholeLineLiteral.hasMatch(lines[end])) {
        end++;
      }

      if (end - index < 2) {
        joined.add(lines[index]);
        index++;
        continue;
      }

      final chain = lines.sublist(index, end);
      final value = chain
          .map((line) => _wholeLineLiteral.firstMatch(line)!.group(1)!)
          .join();
      if (value.contains(r'${') || chain.any((l) => _allowlistedLine(path, l))) {
        joined.addAll(chain);
      } else {
        joined.add("'$value'");
      }
      index = end;
    }

    return joined;
  }

  /// Scans [path] for unsafe privacy promises in string literals.
  static List<String> scanFile(String path, String source) {
    final violations = <String>[];
    final literalPattern = _literalPattern;
    var insideBannedVocabulary = false;

    for (final line in joinAdjacentLiterals(path, source.split('\n'))) {
      if (insideBannedVocabulary) {
        if (line.contains(']') || line.contains('}')) {
          insideBannedVocabulary = false;
        }
        continue;
      }
      if (_allowlistedLine(path, line)) {
        insideBannedVocabulary = _opensBannedVocabularyBlock(line);
        continue;
      }

      for (final match in literalPattern.allMatches(line)) {
        final value = match.group(1) ?? '';
        if (isMachineIdentifierLiteral(value)) continue;
        for (final reason in violationsInLiteral(value)) {
          violations.add('$path: $reason in "$value"');
        }
      }
    }

    return violations;
  }

  /// Scans every entry of [sourcesByPath], skipping paths that are not consumer
  /// privacy surfaces. Returns violations sorted so output is diffable.
  static List<String> scanSources(Map<String, String> sourcesByPath) {
    final violations = <String>[];
    final paths = sourcesByPath.keys.toList()..sort();
    for (final path in paths) {
      if (!isConsumerPrivacySource(path)) continue;
      violations.addAll(scanFile(path, sourcesByPath[path]!));
    }
    return violations;
  }
}
