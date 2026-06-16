import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_error_message.dart';
import '../auth/account_auth.dart';
import '../design/archive_mobile_typography.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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
    final email = _emailController.text.trim();
    if (!AccountAuth.isValidEmail(email)) {
      _showError(AccountAuthCopy.invalidEmail, errorType: 'invalid_email');
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
        _status = AccountAuthCopy.codeSent;
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        userFacingErrorMessage(e, fallback: 'Could not send the code.'),
        errorType: AccountAuth.errorTypeFor(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError(AccountAuthCopy.invalidCode, errorType: 'invalid_code');
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
        userFacingErrorMessage(
          e,
          fallback: 'Sign-in failed. Check the code and try again.',
        ),
        errorType: AccountAuth.errorTypeFor(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('account_auth_screen'),
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
    return [
      Text(
        _isCreate ? AccountAuthCopy.createTitle : AccountAuthCopy.signInTitle,
        key: const Key('account_auth_title'),
        style: ArchiveMobileTypography.responsiveSectionTitle(context),
      ),
      if (_isCreate) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          AccountAuthCopy.createBody,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
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
        decoration: const InputDecoration(
          labelText: AccountAuthCopy.emailLabel,
          border: OutlineInputBorder(),
        ),
      ),
      ..._statusLine(),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const Key('account_auth_primary_cta'),
        onPressed: _busy ? null : () => unawaited(_sendCode()),
        child: Text(
          _isCreate ? AccountAuthCopy.createCta : AccountAuthCopy.signInCta,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        key: const Key('account_auth_skip'),
        onPressed: _busy ? null : () => Navigator.of(context).maybePop(false),
        child: const Text(AccountAuthCopy.continueWithoutAccount),
      ),
      const SizedBox(height: AppSpacing.sm),
      _privacyLine(),
    ];
  }

  List<Widget> _codeStepChildren() {
    return [
      Text(
        AccountAuthCopy.codeTitle,
        key: const Key('account_auth_code_title'),
        style: ArchiveMobileTypography.responsiveSectionTitle(context),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        AccountAuthCopy.codeBody,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const Key('account_auth_code_field'),
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => unawaited(_verifyCode()),
        decoration: const InputDecoration(
          labelText: AccountAuthCopy.codeLabel,
          border: OutlineInputBorder(),
        ),
      ),
      ..._statusLine(),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const Key('account_auth_verify_cta'),
        onPressed: _busy ? null : () => unawaited(_verifyCode()),
        child: const Text(AccountAuthCopy.codeCta),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        key: const Key('account_auth_resend'),
        onPressed: _busy ? null : () => unawaited(_sendCode(resend: true)),
        child: const Text(AccountAuthCopy.resendCode),
      ),
      const SizedBox(height: AppSpacing.sm),
      _privacyLine(),
    ];
  }

  List<Widget> _statusLine() {
    if (_status.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.xs),
      Text(
        _status,
        key: const Key('account_auth_status'),
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: _statusIsError ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    ];
  }

  Widget _privacyLine() {
    return Text(
      AccountAuthCopy.privacyLine,
      key: const Key('account_auth_privacy_line'),
      textAlign: TextAlign.center,
      style: ArchiveMobileTypography.responsiveHelper(
        context,
      ).copyWith(color: AppColors.textSecondary),
    );
  }
}
