export const SIGE_ERROR_CODES = [
  "AUTH_REQUIRED",
  "FORBIDDEN",
  "NOT_FOUND",
  "INVALID_ARGUMENT",
  "IDEMPOTENCY_KEY_REQUIRED",
  "REQUEST_HASH_MISMATCH",
  "ACADEMIC_YEAR_CLOSED",
  "ACADEMIC_YEAR_NOT_OPEN",
  "ASSESSMENT_RESULTS_INCOMPLETE",
  "RESULT_IS_NOT_PUBLISHED",
  "PUBLISHED_RESULT_REQUIRES_CORRECTION",
  "PUBLISHED_RESULT_REQUIRES_CORRECTION_COMMAND",
  "CORRECTION_REASON_REQUIRED",
  "PEDAGOGICAL_PARALLELISM_NOT_CONFIGURED",
  "FINAL_EXAM_ONLY_ALLOWED_FOR_9_AND_12",
  "THREE_PUBLISHED_TRIMESTER_RESULTS_REQUIRED",
  "TRIMESTER_RESULT_INCOMPLETE",
  "FREQUENCY_RESULT_INCOMPLETE",
  "PUBLISHED_FREQUENCY_RESULT_REQUIRED",
  "PUBLISHED_EXAM_RESULT_REQUIRED",
  "EXAM_RESULT_NOT_FOUND",
  "ASSESSMENT_RESULT_IS_NOT_EXAM",
  "SCHEDULE_TEACHER_CONFLICT",
  "TEACHER_ASSIGNMENT_CONTEXT_MISMATCH",
  "COURSE_OFFERING_NOT_FOUND",
  "ASSESSMENT_PERIOD_NOT_FOUND",
  "STUDENT_NOT_COURSE_PARTICIPANT",
  "FINANCIAL_SCOPE_VIOLATION",
  "PAYMENT_ALLOCATION_EXCEEDS_PAYMENT",
  "PAYMENT_ALLOCATION_EXCEEDS_CHARGE",
  "RECEIPT_PAYMENT_NOT_CONFIRMED",
  "PAYMENT_ALREADY_REVERSED",
  "SCHOOL_NOT_FOUND",
  "STUDENT_NOT_FOUND",
  "STUDENT_SCHOOL_NUMBER_ALREADY_EXISTS",
  "NATIONAL_ID_ALREADY_EXISTS",
  "GUARDIAN_IDENTITY_NUMBER_ALREADY_EXISTS",
] as const;

export type SigeErrorCode = (typeof SIGE_ERROR_CODES)[number];

const KNOWN = new Set<string>(SIGE_ERROR_CODES);

export class SigeApplicationError extends Error {
  readonly code: SigeErrorCode | "UNKNOWN";
  readonly details?: unknown;
  readonly cause?: unknown;

  constructor(
    code: SigeErrorCode | "UNKNOWN",
    message: string,
    details?: unknown,
    cause?: unknown,
  ) {
    super(message);
    this.name = "SigeApplicationError";
    this.code = code;
    this.details = details;
    this.cause = cause;
  }
}

export function normalizeSigeError(error: unknown): SigeApplicationError {
  if (error instanceof SigeApplicationError) return error;

  const candidate = error as {
    message?: unknown;
    code?: unknown;
    details?: unknown;
    hint?: unknown;
  } | null;

  const message =
    typeof candidate?.message === "string" ? candidate.message : "Operação SIGE falhou.";
  const code =
    typeof candidate?.code === "string" && KNOWN.has(candidate.code)
      ? (candidate.code as SigeErrorCode)
      : KNOWN.has(message)
        ? (message as SigeErrorCode)
        : "UNKNOWN";

  return new SigeApplicationError(code, message, {
    dbCode: candidate?.code,
    details: candidate?.details,
    hint: candidate?.hint,
  }, error);
}
