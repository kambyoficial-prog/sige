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
export interface TeacherProfile extends TeacherDirectory {
  assignments: Array<{
    course_offering_id: UUID; class_group_id: UUID; class_name: string | null;
    subject_id: UUID; subject_name: string; subject_code: string;
    starts_on: string; ends_on: string | null;
  }>;
}
export interface GuardianDirectory {
  id: UUID; school_id: UUID; person_id: UUID; full_name: string;
  relationship: string | null; occupation: string | null; identity_number: string | null;
  address: string | null; phone: string | null; student_count: number;
}
export interface CourseOfferingDirectory {
  id: UUID; school_id: UUID; academic_year_id: UUID; academic_year_label: string;
  class_group_id: UUID; subject_id: UUID; subject_name: string; subject_code: string;
  curriculum_subject_id: UUID | null; status: string; teacher_id: UUID | null;
  teacher_name: string | null; teacher_starts_on: string | null; teacher_ends_on: string | null;
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
  id: UUID; school_id: UUID; academic_year_id: UUID; class_group_id: UUID;
  section_code: string | null; class_name: string | null; grade_level_id: UUID;
  period_id: UUID; period_ordinal: number; period_code: string; period_name: string;
  starts_at: string; ends_at: string; day_of_week: number;
  course_offering_id: UUID; subject_id: UUID; subject_code: string; subject_name: string;
  teacher_id: UUID; teacher_name: string; room_id: UUID | null;
  room_code: string | null; room_name: string | null;
  valid_from: string; valid_until: string | null; status: string;
}
export interface TeacherWorkloadSummary {
  teacher_id: UUID; academic_year_id: UUID; scheduled_periods: number; assigned_offerings: number;
}
export interface ClassSessionDirectory {
  id: UUID; school_id: UUID; academic_year_id: UUID; session_date: string; status: string;
  topic: string | null; notes: string | null; schedule_entry_id: UUID; teacher_id: UUID;
  teacher_name: string; course_offering_id: UUID; subject_code: string; subject_name: string;
  class_group_id: UUID; section_code: string; class_name: string | null;
  period_ordinal: number; period_code: string; period_name: string;
  starts_at: string; ends_at: string; room_id: UUID | null; room_code: string | null;
  room_name: string | null; attendance_count: number;
}
export interface ClassSessionRoster {
  class_session_id: UUID; session_date: string; session_status: string;
  class_group_id: UUID; enrollment_id: UUID; student_id: UUID; school_number: string;
  student_name: string; attendance_record_id: UUID | null; attendance_status: string | null;
  minutes_late: number | null; reason: string | null; recorded_at: string | null;
}
export interface StudentFinancialBalance {
  school_id: UUID; student_id: UUID; academic_year_id?: UUID;
  charged_amount: number; paid_amount: number; balance_amount: number;
}
export type SigeQueryName =
  | "student_directory" | "student_profile" | "enrollment_directory" | "course_offering_directory"
  | "teacher_directory" | "teacher_profile" | "guardian_directory" | "class_group_directory"
  | "class_group_overview" | "class_group_students" | "class_group_teachers"
  | "class_timetable" | "teacher_timetable" | "student_timetable"
  | "teacher_workload_summary" | "timetable_slot_usage" | "class_session_directory"
  | "class_session_roster" | "student_financial_balances"
  | "academic_year_history" | "assessment_period_history";
