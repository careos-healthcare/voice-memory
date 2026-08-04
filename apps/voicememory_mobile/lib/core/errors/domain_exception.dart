/// An exception whose message and code are safe to use at a UI boundary.
abstract interface class UserFacingException implements Exception {
  String get userMessage;
  String get userFacingCode;
  Object? get cause;
}

/// Base class for failures expressed in application-domain terms.
abstract class DomainException implements UserFacingException {
  const DomainException(
    this.userMessage, {
    required this.userFacingCode,
    this.cause,
  });

  @override
  final String userMessage;

  @override
  final String userFacingCode;

  @override
  final Object? cause;

  @override
  String toString() => userMessage;
}
