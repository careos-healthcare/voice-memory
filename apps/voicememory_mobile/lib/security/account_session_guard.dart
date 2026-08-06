import 'account_session_scope.dart';

/// Captures the active account scope at async start and verifies it before
/// mutating namespaced storage.
class AccountSessionGuard {
  AccountSessionGuard._(this._captured);

  final AccountSessionScope _captured;

  static AccountSessionGuard capture() =>
      AccountSessionGuard._(AccountSessionRegistry.instance.current);

  void assertActive() {
    _captured.assertActive(AccountSessionRegistry.instance.current);
  }
}
