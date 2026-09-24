/// Shared HTTP header names for capture and idempotent API routes.
abstract final class ApiHeaders {
  ApiHeaders._();

  static const captureToken = 'x-vm-capture-token';
  static const idempotencyKey = 'x-vm-idempotency-key';
}
