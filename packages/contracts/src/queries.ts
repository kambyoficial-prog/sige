export type UUID = string;

export interface AcademicYearHistory {
  id: UUID;
  school_id: UUID;
  code: string;
  name: string;
  status: string;
  starts_on: string;
  ends_on: string;
  closed_at: string | null;
}

export interface AssessmentPeriodHistory {
  id: UUID;
  academic_year_id: UUID;
  code: string;
  name: string;
  ordinal: number;
  starts_on: string;
  ends_on: string;
  status: string;
  closed_at: string | null;
}

export interface ClassGroupOverview {
  id: UUID;
  school_id: UUID;
  academic_year_id: UUID;
  grade_level_id: UUID;
  section_code: string;
  name: string | null;
  pathway_id: UUID | null;
  shift: string | null;
  capacity: number | null;
  status: string;
  director_teacher_id: UUID | null;
}

export interface ClassGroupStudent {
  class_group_id: UUID;
  student_id: UUID;
  enrollment_id: UUID;
  student_name: string;
  school_number: string;
  status: string;
}

export interface ClassGroupTeacher {
  class_group_id: UUID;
  teacher_id: UUID;
  teacher_name: string;
  subject_id: UUID | null;
  course_offering_id: UUID | null;
}

export interface TimetableEntry {
  id: UUID;
  school_id: UUID;
  academic_year_id: UUID;
  class_group_id: UUID;
  period_id: UUID;
  day_of_week: number;
  valid_from: string;
  valid_until: string | null;
  status: string;
}

export interface TeacherWorkloadSummary {
  teacher_id: UUID;
  academic_year_id: UUID;
  scheduled_periods: number;
  assigned_offerings: number;
}

export interface StudentFinancialBalance {
  school_id: UUID;
  student_id: UUID;
  academic_year_id?: UUID;
  charged_amount: number;
  paid_amount: number;
  balance: number;
}

export type SigeQueryName =
  | "class_group_overview"
  | "class_group_students"
  | "class_group_teachers"
  | "class_timetable"
  | "teacher_timetable"
  | "student_timetable"
  | "teacher_workload_summary"
  | "timetable_slot_usage"
  | "student_financial_balances"
  | "academic_year_history"
  | "assessment_period_history";
