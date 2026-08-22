/** Finite public API error codes — safe to expose to clients. */
export const PUBLIC_API_ERROR_CODES = {
  AUTH_REQUIRED: {
    message: "Sign in required.",
    retryable: false,
    httpStatus: 401,
  },
  AUTH_INVALID_REQUEST: {
    message: "Request body must be valid JSON.",
    retryable: false,
    httpStatus: 400,
  },
  AUTH_EMAIL_REQUIRED: {
    message: "Email is required.",
    retryable: false,
    httpStatus: 400,
  },
  AUTH_RATE_LIMITED: {
    message: "Too many requests. Try again shortly.",
    retryable: true,
    httpStatus: 429,
  },
  AUTH_STORAGE_NOT_CONFIGURED: {
    message: "Auth storage is not configured.",
    retryable: false,
    httpStatus: 503,
  },
  AUTH_DATABASE_FAILED: {
    message: "Sign-in storage is temporarily unavailable.",
    retryable: true,
    httpStatus: 503,
  },
  AUTH_EMAIL_SEND_FAILED: {
    message: "Email delivery is temporarily unavailable.",
    retryable: true,
    httpStatus: 502,
  },
  AUTH_RESEND_NOT_CONFIGURED: {
    message: "Email delivery is temporarily unavailable.",
    retryable: false,
    httpStatus: 503,
  },
  AUTH_INVALID_EMAIL_FROM: {
    message: "Auth email provider rejected the sender address.",
    retryable: false,
    httpStatus: 502,
  },
  AUTH_RESEND_REJECTED: {
    message: "Auth email provider rejected the sender address.",
    retryable: false,
    httpStatus: 502,
  },
  CONFIRM_REQUIRED: {
    message: "Confirmation required.",
    retryable: false,
    httpStatus: 400,
  },
  ACCOUNT_DELETE_PARTIAL: {
    message:
      "Server account data deletion was only partially completed. Some data may remain — contact support if this persists.",
    retryable: false,
    httpStatus: 207,
  },
  SESSION_REVOKE_FAILED: {
    message: "Account data was removed but the active session could not be revoked.",
    retryable: false,
    httpStatus: 207,
  },
  SYNC_AUTH_REQUIRED: {
    message: "Sign in required.",
    retryable: false,
    httpStatus: 401,
  },
  INVALID_REMOTE_JSON: {
    message: "Request body must be valid JSON.",
    retryable: false,
    httpStatus: 400,
  },
  SYNC_PUSH_TOO_LARGE: {
    message: "Encrypted sync payload too large.",
    retryable: false,
    httpStatus: 413,
  },
  SYNC_PUSH_TOO_MANY_BLOBS: {
    message: "Too many encrypted blobs in one push.",
    retryable: false,
    httpStatus: 400,
  },
  EMPTY_REMOTE_PAYLOAD: {
    message: "No encrypted blobs provided.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_ENCRYPTED_ENVELOPE: {
    message: "Invalid encrypted blob envelope.",
    retryable: false,
    httpStatus: 400,
  },
  SYNC_BLOB_TOO_LARGE: {
    message: "Encrypted blob exceeds size limit.",
    retryable: false,
    httpStatus: 413,
  },
  INVALID_REMOTE_TIMESTAMP: {
    message: "Blob updatedAt timestamp is invalid.",
    retryable: false,
    httpStatus: 400,
  },
  UNSUPPORTED_ENCRYPTION_VERSION: {
    message: "Unsupported encryption version.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_SYNC_CURSOR: {
    message: "Query parameter since must be a non-negative integer.",
    retryable: false,
    httpStatus: 400,
  },
  SYNC_PUSH_FAILED: {
    message: "Encrypted backup could not be saved.",
    retryable: true,
    httpStatus: 500,
  },
  SYNC_PULL_FAILED: {
    message: "Could not read encrypted backup.",
    retryable: true,
    httpStatus: 500,
  },
  SYNC_MANIFEST_FAILED: {
    message: "Could not read sync manifest.",
    retryable: true,
    httpStatus: 500,
  },
  SYNC_CHANGES_FAILED: {
    message: "Could not read sync changes.",
    retryable: true,
    httpStatus: 500,
  },
  VALIDATION_ERROR: {
    message: "Request validation failed.",
    retryable: false,
    httpStatus: 400,
  },
  FORBIDDEN: {
    message: "You do not have permission to perform this action.",
    retryable: false,
    httpStatus: 403,
  },
  RATE_LIMIT_MINUTE: {
    message: "Too many requests. Wait a minute and try again.",
    retryable: true,
    httpStatus: 429,
  },
  RATE_LIMIT_DAILY: {
    message: "Daily limit reached. Try again tomorrow.",
    retryable: true,
    httpStatus: 429,
  },
  PAYLOAD_TOO_LARGE: {
    message: "Request payload is too large.",
    retryable: false,
    httpStatus: 413,
  },
  CONFLICT: {
    message: "Request could not be completed because of a conflict.",
    retryable: false,
    httpStatus: 409,
  },
  UPSTREAM_UNAVAILABLE: {
    message: "Service is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 503,
  },
  TRANSCRIBE_UNAVAILABLE: {
    message: "Voice processing is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 503,
  },
  ANALYZE_UNAVAILABLE: {
    message: "Voice processing is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 503,
  },
  ATMOSPHERE_UNAVAILABLE: {
    message: "Voice processing is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 503,
  },
  ATTEST_UNAVAILABLE: {
    message: "Device attestation is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 503,
  },
  OPENAI_DISABLED: {
    message: "Voice processing is temporarily unavailable. Please try again later.",
    retryable: true,
    httpStatus: 429,
  },
  OPENAI_BUDGET_EXCEEDED: {
    message: "Voice processing is temporarily limited. Please try again later.",
    retryable: true,
    httpStatus: 429,
  },
  OPENAI_PLATFORM_LIMIT: {
    message: "Voice processing is temporarily limited. Please try again later.",
    retryable: true,
    httpStatus: 429,
  },
  missing_capture_token: {
    message: "Capture token is required before using voice analysis.",
    retryable: false,
    httpStatus: 401,
  },
  unauthorized_capture_token: {
    message: "Sign in or attest this device before using voice analysis.",
    retryable: false,
    httpStatus: 401,
  },
  INTERNAL_ERROR: {
    message: "Something went wrong. Please try again later.",
    retryable: true,
    httpStatus: 500,
  },
  METHOD_NOT_ALLOWED: {
    message: "HTTP method not allowed for this route.",
    retryable: false,
    httpStatus: 405,
  },
  AUDIO_REQUIRED: {
    message: "Audio file is required.",
    retryable: false,
    httpStatus: 400,
  },
  DURATION_LIMIT: {
    message: "Recording exceeds the allowed duration.",
    retryable: false,
    httpStatus: 400,
  },
  NO_SPEECH: {
    message: "Could not detect speech in the recording.",
    retryable: false,
    httpStatus: 422,
  },
  GEMINI_NOT_CONFIGURED: {
    message: "Embeddings are not configured on the server.",
    retryable: false,
    httpStatus: 503,
  },
  OPENAI_NOT_CONFIGURED: {
    message: "Insights are not configured on the server.",
    retryable: false,
    httpStatus: 503,
  },
  INVALID_REQUEST: {
    message: "Request validation failed.",
    retryable: false,
    httpStatus: 400,
  },
  TRANSCRIPT_REQUIRED: {
    message: "Transcript is required.",
    retryable: false,
    httpStatus: 400,
  },
  TRANSCRIPT_TOO_LONG: {
    message: "Transcript is too long.",
    retryable: false,
    httpStatus: 413,
  },
  INSIGHT_GENERATION_FAILED: {
    message: "Failed to generate evidence-backed insight.",
    retryable: true,
    httpStatus: 500,
  },
  BULK_IMPORT_FAILED: {
    message: "Bulk import failed.",
    retryable: true,
    httpStatus: 500,
  },
  CHUNKS_REQUIRED: {
    message: "At least one valid chunk is required.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_CHUNK: {
    message: "One or more import chunks are invalid.",
    retryable: false,
    httpStatus: 400,
  },
  TRANSCRIBE_BLOCKED: {
    message: "Transcription request could not be processed.",
    retryable: false,
    httpStatus: 400,
  },
  PARTIAL_DELETION: {
    message: "User data deletion was only partially completed.",
    retryable: false,
    httpStatus: 502,
  },
  USER_DATA_DELETE_FAILED: {
    message: "Failed to delete user data.",
    retryable: true,
    httpStatus: 500,
  },
  INVALID_BODY: {
    message: "Request body is invalid.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_CAREGIVER_ID: {
    message: "caregiverId is required.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_PERMISSIONS: {
    message: "permissions are required.",
    retryable: false,
    httpStatus: 400,
  },
  CAREGIVER_CONSENT_ISSUE_FAILED: {
    message: "Caregiver consent issuance failed.",
    retryable: true,
    httpStatus: 503,
  },
  INVALID_COACH_ID: {
    message: "coachId is required.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_AFFIRMATION: {
    message: "clientAffirmationHash is required.",
    retryable: false,
    httpStatus: 400,
  },
  COACH_CONSENT_ISSUE_FAILED: {
    message: "Coach consent issuance failed.",
    retryable: true,
    httpStatus: 503,
  },
  SYNTHESIS_DISABLED: {
    message: "Archive synthesis is not enabled.",
    retryable: false,
    httpStatus: 403,
  },
  INVALID_PACK: {
    message: "Archive pack validation failed.",
    retryable: false,
    httpStatus: 400,
  },
  SYNTHESIS_REQUIRES_AUTH: {
    message: "Sign in required for Archive Intelligence.",
    retryable: false,
    httpStatus: 403,
  },
  SYNTHESIS_VALIDATION_FAILED: {
    message: "Synthesis failed evidence checks.",
    retryable: false,
    httpStatus: 422,
  },
  INSUFFICIENT_EVIDENCE: {
    message: "Not enough evidence to generate this insight.",
    retryable: false,
    httpStatus: 422,
  },
  WEEKLY_STORY_GENERATION_FAILED: {
    message: "Failed to generate weekly story.",
    retryable: true,
    httpStatus: 500,
  },
  INSIGHT_ID_REQUIRED: {
    message: "insightId is required.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_CORRECTION_REASON: {
    message: "Invalid correction reason.",
    retryable: false,
    httpStatus: 400,
  },
  INSIGHT_CORRECTION_FAILED: {
    message: "Failed to store insight correction.",
    retryable: true,
    httpStatus: 500,
  },
  CURIOSITY_DISPATCH_FAILED: {
    message: "Curiosity loop dispatch failed.",
    retryable: true,
    httpStatus: 500,
  },
  RELATIONSHIPS_LIST_FAILED: {
    message: "Failed to load relationships.",
    retryable: true,
    httpStatus: 500,
  },
  INVALID_PARTIES: {
    message: "clientId and professionalId are required.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_CONSENT_STATUS: {
    message: "consentStatus is required.",
    retryable: false,
    httpStatus: 400,
  },
  RELATIONSHIPS_UPSERT_FAILED: {
    message: "Failed to save relationship.",
    retryable: true,
    httpStatus: 500,
  },
  INVALID_ID: {
    message: "Resource id is required.",
    retryable: false,
    httpStatus: 400,
  },
  NOT_FOUND: {
    message: "Resource not found.",
    retryable: false,
    httpStatus: 404,
  },
  RELATIONSHIPS_UPDATE_FAILED: {
    message: "Failed to update relationship.",
    retryable: true,
    httpStatus: 500,
  },
  COMPARISON_GENERATION_FAILED: {
    message: "Failed to generate then-vs-now comparison.",
    retryable: true,
    httpStatus: 500,
  },
  INVALID_TOKEN: {
    message: "token is required.",
    retryable: false,
    httpStatus: 400,
  },
  CAREGIVER_CONSENT_VERIFY_FAILED: {
    message: "Caregiver consent verification failed.",
    retryable: true,
    httpStatus: 503,
  },
  COACH_CONSENT_VERIFY_FAILED: {
    message: "Coach consent verification failed.",
    retryable: true,
    httpStatus: 503,
  },
  INVALID_TOKEN_ID: {
    message: "tokenId is required.",
    retryable: false,
    httpStatus: 400,
  },
  CONSENT_REVOKE_FAILED: {
    message:
      "Access was not revoked on the server — this device has stopped accepting the grant and will retry.",
    retryable: true,
    httpStatus: 503,
  },
  OWNER_CONFIRMATION_REQUIRED: {
    message: "Renewing this access needs a fresh confirmation from its owner.",
    retryable: false,
    httpStatus: 400,
  },
  GRANT_EXPIRED: {
    message:
      "This access window has ended. Granting access again starts a new one.",
    retryable: false,
    httpStatus: 409,
  },
  GRANT_NOT_RENEWABLE: {
    message: "This access grant cannot be renewed as it stands.",
    retryable: false,
    httpStatus: 409,
  },
  CONSENT_RENEWAL_FAILED: {
    message:
      "Renewal did not finish on the server. The current access window is unchanged.",
    retryable: true,
    httpStatus: 503,
  },
  ENTRY_ID_REQUIRED: {
    message: "entryId is required.",
    retryable: false,
    httpStatus: 400,
  },
  BRAIN_DUMP_UPLOAD_FAILED: {
    message: "Failed to store brain dump upload.",
    retryable: true,
    httpStatus: 500,
  },
  ID_MISMATCH: {
    message: "entry.id must match the route id.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_LIMIT: {
    message: "limit must be a positive integer.",
    retryable: false,
    httpStatus: 400,
  },
  BATCH_TOO_LARGE: {
    message: "Request batch exceeds the allowed size.",
    retryable: false,
    httpStatus: 400,
  },
  IDEMPOTENCY_REQUIRED: {
    message: "Idempotency key is required for vault recovery uploads.",
    retryable: false,
    httpStatus: 400,
  },
  VAULT_REQUIRED: {
    message: "Encrypted vault file is required.",
    retryable: false,
    httpStatus: 400,
  },
  SESSION_ID_REQUIRED: {
    message: "sessionId is required.",
    retryable: false,
    httpStatus: 400,
  },
  RECOVERY_SECRET_INVALID: {
    message: "recovery_secret must be 32-byte base64url, base64, or hex.",
    retryable: false,
    httpStatus: 400,
  },
  RECOVERY_SECRET_MISMATCH: {
    message: "Provided recovery secret does not match the registered session.",
    retryable: false,
    httpStatus: 403,
  },
  VAULT_RECOVERY_EXPIRED: {
    message: "Vault recovery window expired.",
    retryable: false,
    httpStatus: 410,
  },
  VAULT_SESSION_UNKNOWN: {
    message: "Unknown or unauthorized vault session.",
    retryable: false,
    httpStatus: 404,
  },
  MODEL_ERROR: {
    message: "Model processing failed.",
    retryable: true,
    httpStatus: 502,
  },
  BILLING_DISABLED: {
    message: "Billing is not configured.",
    retryable: false,
    httpStatus: 503,
  },
  CHECKOUT_FAILED: {
    message: "Could not start checkout.",
    retryable: true,
    httpStatus: 500,
  },
  WEBHOOK_MISSING_SIGNATURE: {
    message: "Missing webhook signature.",
    retryable: false,
    httpStatus: 400,
  },
  WEBHOOK_INVALID_SIGNATURE: {
    message: "Invalid webhook signature.",
    retryable: false,
    httpStatus: 400,
  },
  WEBHOOK_HANDLER_FAILED: {
    message: "Webhook handler failed.",
    retryable: true,
    httpStatus: 500,
  },
  FEEDBACK_AUTH_REQUIRED: {
    message: "Sign in required for server feedback.",
    retryable: false,
    httpStatus: 401,
  },
  FEEDBACK_RAW_REJECTED: {
    message: "Raw journal content not accepted.",
    retryable: false,
    httpStatus: 400,
  },
  FEEDBACK_INVALID_BODY: {
    message: "Invalid feedback body.",
    retryable: false,
    httpStatus: 400,
  },
  FEEDBACK_INVALID_TYPE: {
    message: "Invalid feedback type.",
    retryable: false,
    httpStatus: 400,
  },
  FEEDBACK_INVALID_PHRASE: {
    message: "Invalid phrase key.",
    retryable: false,
    httpStatus: 400,
  },
  CAPTURE_AUTH_REQUIRED: {
    message: "Auth required.",
    retryable: false,
    httpStatus: 401,
  },
  CAPTURE_INVALID_EVENT: {
    message: "Invalid resurfacing event.",
    retryable: false,
    httpStatus: 400,
  },
  INVALID_DEVICE: {
    message: "Valid deviceId (UUID) is required.",
    retryable: false,
    httpStatus: 400,
  },
  ATTEST_FAILED: {
    message: "Could not issue capture token.",
    retryable: true,
    httpStatus: 500,
  },
  AUTH_CODE_REQUIRED: {
    message: "Email and code are required.",
    retryable: false,
    httpStatus: 400,
  },
  AUTH_CODE_INVALID: {
    message: "Invalid or expired code.",
    retryable: false,
    httpStatus: 401,
  },
  AUTH_VERIFY_FAILED: {
    message: "Sign-in failed.",
    retryable: false,
    httpStatus: 400,
  },
  AUTH_SESSION_FAILED: {
    message: "Session lookup failed.",
    retryable: true,
    httpStatus: 503,
  },
  PUSH_INVALID_JSON: {
    message: "Request body must be valid JSON.",
    retryable: false,
    httpStatus: 400,
  },
  PUSH_INVALID_DEVICE: {
    message: "Valid deviceId required.",
    retryable: false,
    httpStatus: 400,
  },
  PUSH_INVALID_PLATFORM: {
    message: "platform must be ios or android.",
    retryable: false,
    httpStatus: 400,
  },
  PUSH_INVALID_TOKEN: {
    message: "Valid fcmToken required.",
    retryable: false,
    httpStatus: 400,
  },
  PUSH_REGISTRATION_FAILED: {
    message: "Push registration failed.",
    retryable: true,
    httpStatus: 500,
  },
  FCM_NOT_CONFIGURED: {
    message: "FCM is not configured.",
    retryable: false,
    httpStatus: 503,
  },
  DEVICE_NOT_REGISTERED: {
    message: "Device not registered — open app and grant push permission first.",
    retryable: false,
    httpStatus: 404,
  },
  STALE_TOKEN: {
    message: "Stale FCM token removed — re-register on device.",
    retryable: false,
    httpStatus: 410,
  },
  FCM_SEND_FAILED: {
    message: "FCM send failed.",
    retryable: true,
    httpStatus: 502,
  },
  PUSH_INVALID_TARGET_ROUTE: {
    message: "targetRoute must be /archive-belief, /discover, or /record.",
    retryable: false,
    httpStatus: 400,
  },
  ARCHIVE_REVIEW_INVALID_JSON: {
    message: "Request body must be valid JSON.",
    retryable: false,
    httpStatus: 400,
  },
  ARCHIVE_REVIEW_INVALID_EMAIL: {
    message: "Valid email required.",
    retryable: false,
    httpStatus: 400,
  },
  ARCHIVE_REVIEW_URL_REQUIRED: {
    message: "archiveUrl required.",
    retryable: false,
    httpStatus: 400,
  },
  ARCHIVE_REVIEW_INVALID: {
    message: "review must be ArchiveMonthlyReview v2 from synthesis cache.",
    retryable: false,
    httpStatus: 400,
  },
  ARCHIVE_REVIEW_SEND_FAILED: {
    message: "Archive review email send failed.",
    retryable: true,
    httpStatus: 502,
  },
  JOURNAL_NOT_FOUND: {
    message: "Journal entry not found.",
    retryable: false,
    httpStatus: 404,
  },
  WEEKLY_REFLECTION_NO_ENTRIES: {
    message: "No entries in the current week window.",
    retryable: false,
    httpStatus: 400,
  },
  WEEKLY_REFLECTION_NO_SUMMARY: {
    message: "No summary returned from model.",
    retryable: true,
    httpStatus: 502,
  },
  WEBSOCKET_UPGRADE_REQUIRED: {
    message: "WebSocket upgrade required for live audio proxy.",
    retryable: false,
    httpStatus: 426,
  },
} as const;

export type PublicApiErrorCode = keyof typeof PUBLIC_API_ERROR_CODES;

export type PublicApiErrorDefinition = (typeof PUBLIC_API_ERROR_CODES)[PublicApiErrorCode];

export function resolvePublicApiError(
  code: PublicApiErrorCode | string,
  overrides?: { message?: string; retryable?: boolean; httpStatus?: number },
): {
  code: string;
  message: string;
  retryable: boolean;
  httpStatus: number;
} {
  const catalog = PUBLIC_API_ERROR_CODES[code as PublicApiErrorCode];
  return {
    code,
    message: overrides?.message ?? catalog?.message ?? "Request failed.",
    retryable: overrides?.retryable ?? catalog?.retryable ?? false,
    httpStatus: overrides?.httpStatus ?? catalog?.httpStatus ?? 500,
  };
}
