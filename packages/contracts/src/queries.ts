export type UUID = string;

export interface AcademicYearHistory {
  id: UUID; school_id: UUID; code: string; name: string; status: string;
  starts_on: string; ends_on: string; closed_at: string | null;
}
export interface AssessmentPeriodHistory {
  id: UUID; academic_year_id: UUID; code: string; name: string; ordinal: number;
  starts_on: string; ends_on: string; status: string; closed_at: string | null;
}
export interface StudentDirectory {
  id: UUID; school_id: UUID; school_number: string; status: string;
  admission_date: string | null; full_name: string; first_name: string | null;
  last_name: string | null; gender: string | null; birth_date: string | null;
  phone: string | null; email: string | null; address: string | null; enrollment_id: UUID | null;
  academic_year_id: UUID | null; academic_year_label: string | null; grade_level_id: UUID | null; grade_level_name: string | null;
  enrollment_status: string | null; enrolled_on: string | null;
  class_group_id: UUID | null; class_name: string | null; section_code: string | null;
}
export interface StudentProfile extends StudentDirectory {
  guardians: Array<{
    id: UUID; full_name: string; relationship: string | null;
    occupation: string | null; identity_number: string | null; address: string | null;
    phone: string | null; is_primary: boolean; lives_with_student: boolean | null;
  }>;
  identifiers: Array<{ id: UUID; type: string; value: string }>;
}
export interface EnrollmentDirectory {
  id: UUID; school_id: UUID; student_id: UUID; school_number: string;
  student_name: string; academic_year_id: UUID; academic_year_label: string;
  grade_level_id: UUID; grade_level_name: string; status: string; entry_type: string;
  enrolled_on: string; exited_on: string | null; exit_reason: string | null;
  enrollment_sequence: number; class_group_id: UUID | null; class_name: string | null;
}
export interface TeacherDirectory {
  id: UUID; school_id: UUID; employee_code: string; status: string;
  full_name: string; first_name: string | null; last_name: string | null;
  phone: string | null; email: string | null;
}
export interface GuardianDirectory {
  id: UUID; school_id: UUID; person_id: UUID; full_name: string;
  relationship: string | null; occupation: string | null; identity_number: string | null;
  address: string | null; phone: string | null; student_count: number;
}
export interface ClassGroupDirectory {
  id: UUID; school_id: UUID; academic_year_id: UUID; academic_year_label: string;
  grade_level_id: UUID; grade_level_name: string; academic_cycle_name: string;
  education_level_name: string; section_code: string; name: string | null;
  status: string; shift: string | null; capacity: number | null; student_count: number;
  director_teacher_id: UUID | null; director_teacher_name: string | null;
}
export interface ClassGroupOverview {
  id: UUID; school_id: UUID; academic_year_id: UUID; grade_level_id: UUID;
  section_code: string; name: string | null; pathway_id: UUID | null; shift: string | null;
  capacity: number | null; status: string; director_teacher_id: UUID | null;
}
export interface ClassGroupStudent {
  class_group_id: UUID; student_id: UUID; enrollment_id: UUID; student_name: string;
  school_number: string; status: string;
}
export interface ClassGroupTeacher {
  class_group_id: UUID; teacher_id: UUID; teacher_name: string;
  subject_id: UUID | null; course_offering_id: UUID | null;
}
export interface TimetableEntry {
  id: UUID; school_id: UUID; academic_year_id: UUID; class_group_id: UUID; period_id: UUID;
  day_of_week: number; valid_from: string; valid_until: string | null; status: string;
}
export interface TeacherWorkloadSummary {
  teacher_id: UUID; academic_year_id: UUID; scheduled_periods: number; assigned_offerings: number;
}
export interface StudentFinancialBalance {
  school_id: UUID; student_id: UUID; academic_year_id?: UUID;
  charged_amount: number; paid_amount: number; balance_amount: number;
}
export type SigeQueryName =
  | "student_directory" | "student_profile" | "enrollment_directory"
  | "teacher_directory" | "guardian_directory" | "class_group_directory"
  | "class_group_overview" | "class_group_students" | "class_group_teachers"
  | "class_timetable" | "teacher_timetable" | "student_timetable"
  | "teacher_workload_summary" | "timetable_slot_usage" | "student_financial_balances"
  | "academic_year_history" | "assessment_period_history";
