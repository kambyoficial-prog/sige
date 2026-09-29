export type CommandName =
  | "enroll_student"
  | "place_student_in_class"
  | "transfer_student_out"
  | "withdraw_student"
  | "create_assessment"
  | "save_assessment_result"
  | "publish_assessment"
  | "correct_published_result"
  | "close_assessment_period"
  | "issue_charge"
  | "confirm_payment"
  | "allocate_payment"
  | "adjust_charge"
  | "reverse_payment"
  | "open_academic_year"
  | "close_academic_year";

export interface CommandContext {
  commandId: string;
  actorAuthUserId: string;
  schoolId: string;
  idempotencyKey: string;
  expectedVersion?: number;
  reason?: string;
}

export interface CommandResult<T> {
  commandId: string;
  entityId: string;
  version: number;
  auditEventId: string;
  value: T;
}

export interface EnrollStudentInput {
  context: CommandContext;
  studentId: string;
  academicYearId: string;
  gradeLevelId: string;
}

export interface PlaceStudentInClassInput {
  context: CommandContext;
  enrollmentId: string;
  classGroupId: string;
  startsOn: string;
  endsOn?: string;
}

export interface ConfirmPaymentInput {
  context: CommandContext;
  paymentId: string;
  amount: number;
  receivedAt: string;
}

export function assertCommandContext(context: CommandContext): void {
  if (!context.commandId || !context.actorAuthUserId || !context.schoolId) {
    throw new Error("A command requires actor, school and command identity.");
  }

  if (!context.idempotencyKey) {
    throw new Error("Critical commands require an idempotency key.");
  }

  if (context.reason !== undefined && context.reason.trim().length === 0) {
    throw new Error("A supplied command reason cannot be empty.");
  }
}
