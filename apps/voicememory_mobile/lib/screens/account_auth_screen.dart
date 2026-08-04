import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_error_message.dart';
import '../auth/account_auth.dart';
import '../design/archive_mobile_typography.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/archive_semantic_colors.dart';

/// Whether this screen was opened to create an account or to sign in.
/// Both ride the same passwordless provider (email + one-time code) — the
/// intent only changes the copy and which funnel events fire.
enum AccountAuthIntent { createAccount, signIn }

/// Create-account / sign-in screen over the existing backend email-code
/// provider. Two steps: email, then the emailed code. No password fields
/// exist anywhere in this flow; "Resend code" doubles as account recovery.
/// Local-only use stays available via "Continue without an account".
class AccountAuthScreen extends StatefulWidget {
  const AccountAuthScreen({super.key, required this.intent, this.service});

  final AccountAuthIntent intent;

  /// Injectable for tests; defaults to the app-wide [AuthService].
  final AuthService? service;

  @override
  State<AccountAuthScreen> createState() => _AccountAuthScreenState();
}

class _AccountAuthScreenState extends State<AccountAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _codeStep = false;
  bool _busy = false;
  String _status = '';
  bool _statusIsError = false;
  bool _startedTracked = false;

  AuthService get _auth => widget.service ?? AppServices.instance.auth;

  bool get _isCreate => widget.intent == AccountAuthIntent.createAccount;

  @override
  void initState() {
    super.initState();
    unawaited(_prefillLastEmail());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _prefillLastEmail() async {
    if (_isCreate) return;
    try {
      final last = await _auth.lastEmail();
      if (!mounted || last == null || _emailController.text.isNotEmpty) return;
      setState(() => _emailController.text = last);
    } catch (_) {
      // Prefill is best-effort only.
    }
  }

  void _trackStartedOnce() {
    if (_startedTracked) return;
    _startedTracked = true;
    ActivationFunnelAnalytics.track(
      _isCreate
          ? ActivationFunnelAnalytics.accountSignupStarted
          : ActivationFunnelAnalytics.accountSigninStarted,
      method: AccountAuth.method,
    );
  }

  void _showError(String message, {required String errorType}) {
    setState(() {
      _status = message;
      _statusIsError = true;
    });
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.authErrorShown,
      errorType: errorType,
    );
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (!AccountAuth.isValidEmail(email)) {
      _showError(l10n.accountAuthInvalidEmail, errorType: 'invalid_email');
      return;
    }
    if (!resend) _trackStartedOnce();
    setState(() {
      _busy = true;
      _status = '';
      _statusIsError = false;
    });
    try {
      await _auth.sendAuthCode(email);
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _status = l10n.accountAuthCodeSent;
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        userFacingErrorMessage(e, fallback: l10n.accountAuthSendCodeFailed),
        errorType: AccountAuth.errorTypeFor(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError(l10n.accountAuthInvalidCode, errorType: 'invalid_code');
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
      _statusIsError = false;
    });
    try {
      await _auth.verifyAuthCode(
        email: _emailController.text.trim(),
        code: code,
      );
      ActivationFunnelAnalytics.track(
        _isCreate
            ? ActivationFunnelAnalytics.accountSignupCompleted
            : ActivationFunnelAnalytics.accountSigninCompleted,
        method: AccountAuth.method,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      _showError(
        userFacingErrorMessage(e, fallback: l10n.accountAuthSignInFailed),
        errorType: AccountAuth.errorTypeFor(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
    return Scaffold(
      key: const Key('account_auth_screen'),
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.primaryText,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _codeStep ? _codeStepChildren() : _emailStepChildren(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStepChildren() {
    final l10n = AppLocalizations.of(context);
    final colors = ArchiveSemanticColors.of(context);
    return [
      Text(
        _isCreate ? l10n.accountAuthCreateTitle : l10n.accountAuthSignInTitle,
        key: const Key('account_auth_title'),
        style: ArchiveMobileTypography.responsiveSectionTitle(context),
      ),
      if (_isCreate) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.accountAuthCreateBody,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: colors.secondaryText),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const Key('account_auth_email_field'),
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofocus: true,
        onSubmitted: (_) => unawaited(_sendCode()),
        decoration: InputDecoration(
          labelText: l10n.accountAuthEmailLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      ..._statusLine(),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const Key('account_auth_primary_cta'),
        onPressed: _busy ? null : () => unawaited(_sendCode()),
        child: Text(
          _isCreate ? l10n.accountAuthCreateCta : l10n.accountAuthSignInCta,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        key: const Key('account_auth_skip'),
        onPressed: _busy ? null : () => Navigator.of(context).maybePop(false),
        child: Text(l10n.accountAuthContinueWithoutAccount),
      ),
      const SizedBox(height: AppSpacing.sm),
      _privacyLine(),
    ];
  }

  List<Widget> _codeStepChildren() {
    final l10n = AppLocalizations.of(context);
    final colors = ArchiveSemanticColors.of(context);
    return [
      Text(
        l10n.accountAuthCodeTitle,
        key: const Key('account_auth_code_title'),
        style: ArchiveMobileTypography.responsiveSectionTitle(context),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        l10n.accountAuthCodeBody,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: colors.secondaryText),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const Key('account_auth_code_field'),
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => unawaited(_verifyCode()),
        decoration: InputDecoration(
          labelText: l10n.accountAuthCodeLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      ..._statusLine(),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const Key('account_auth_verify_cta'),
        onPressed: _busy ? null : () => unawaited(_verifyCode()),
        child: Text(l10n.accountAuthCodeCta),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        key: const Key('account_auth_resend'),
        onPressed: _busy ? null : () => unawaited(_sendCode(resend: true)),
        child: Text(l10n.accountAuthResendCode),
      ),
      const SizedBox(height: AppSpacing.sm),
      _privacyLine(),
    ];
  }

  List<Widget> _statusLine() {
    if (_status.isEmpty) return const [];
    final colors = ArchiveSemanticColors.of(context);
    return [
      const SizedBox(height: AppSpacing.xs),
      Text(
        _status,
        key: const Key('account_auth_status'),
        // Error and information differ only in colour on screen, so the
        // failure state is named for assistive technology as well.
        semanticsLabel: _statusIsError ? 'Error: $_status' : _status,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: _statusIsError ? colors.destructive : colors.secondaryText,
        ),
      ),
    ];
  }

  Widget _privacyLine() {
    return Text(
      AppLocalizations.of(context).accountAuthPrivacyLine,
      key: const Key('account_auth_privacy_line'),
      textAlign: TextAlign.center,
      style: ArchiveMobileTypography.responsiveHelper(
        context,
      ).copyWith(color: ArchiveSemanticColors.of(context).secondaryText),
    );
  }
}
