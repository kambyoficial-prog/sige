export type AcademicYearStatus = "DRAFT" | "OPEN" | "CLOSED";
export type EnrollmentStatus = "PENDING" | "ACTIVE" | "TRANSFERRED_IN" | "TRANSFERRED_OUT" | "WITHDRAWN" | "CANCELLED" | "COMPLETED";
export type AssessmentType = "ACS" | "AT" | "EXAM" | "OTHER";
export type AssessmentResultStatus = "MISSING" | "ENTERED" | "ABSENT" | "EXCUSED" | "INVALIDATED" | "PUBLISHED";
export type StudentStatus = "ACTIVE" | "INACTIVE" | "ARCHIVED";

export interface AcademicYear {
  id: string;
  label: string;
  status: AcademicYearStatus;
  startsOn: string;
  endsOn: string;
}

export interface Student {
  id: string;
  personId: string;
  schoolNumber: string;
  status: StudentStatus;
}

export interface AssessmentDefinition {
  id: string;
  courseOfferingId: string;
  type: AssessmentType;
  title: string;
  maxScore: number;
  weight: number | null;
}

export interface AssessmentResult {
  id: string;
  assessmentId: string;
  studentId: string;
  rawScore: number | null;
  status: AssessmentResultStatus;
}

export function assertScoreInScale(score: number, maxScore = 20): void {
  if (!Number.isFinite(score) || score < 0 || score > maxScore) {
    throw new RangeError(`Score must be between 0 and ${maxScore}.`);
  }
}

export function mean(values: readonly number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

export * from './assessment.js';
export * from './commands.js';
