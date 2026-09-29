import "server-only";

import {
  type AcademicYearHistory,
  type AssessmentPeriodHistory,
  type ClassGroupOverview,
  type ClassGroupStudent,
  type ClassGroupTeacher,
  type StudentFinancialBalance,
  type TeacherWorkloadSummary,
  type TimetableEntry,
  normalizeSigeError,
} from "@sige/contracts";

import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

type ViewName =
  | "student_directory"
  | "student_profile"
  | "enrollment_directory"
  | "teacher_directory"
  | "guardian_directory"
  | "class_group_directory"
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

export async function queryView<T extends object>(
  view: ViewName,
  filters: Record<string, string | number | boolean | null>,
): Promise<T[]> {
  const { supabase } = await requireAuthenticatedServerClient();

  try {
    let query = supabase.from(view).select("*");

    for (const [column, value] of Object.entries(filters)) {
      if (value === null) query = query.is(column, null);
      else query = query.eq(column, value);
    }

    const { data, error } = await query;
    if (error) throw error;

    return (data ?? []) as T[];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export const getStudentDirectory = () =>
  queryView<import("@sige/contracts").StudentDirectory>("student_directory", {});

export const getStudentProfile = (studentId: string) =>
  queryView<import("@sige/contracts").StudentProfile>("student_profile", { id: studentId });

export const getEnrollmentDirectory = () =>
  queryView<import("@sige/contracts").EnrollmentDirectory>("enrollment_directory", {});

export const getTeacherDirectory = () =>
  queryView<import("@sige/contracts").TeacherDirectory>("teacher_directory", {});

export const getGuardianDirectory = () =>
  queryView<import("@sige/contracts").GuardianDirectory>("guardian_directory", {});

export const getClassGroupDirectory = (academicYearId?: string) =>
  queryView<import("@sige/contracts").ClassGroupDirectory>("class_group_directory",
    academicYearId ? { academic_year_id: academicYearId } : {});

export const getClassGroupOverview = (academicYearId: string) =>
  queryView<ClassGroupOverview>("class_group_overview", {
    academic_year_id: academicYearId,
  });

export const getClassGroupStudents = (classGroupId: string) =>
  queryView<ClassGroupStudent>("class_group_students", {
    class_group_id: classGroupId,
  });

export const getClassGroupTeachers = (classGroupId: string) =>
  queryView<ClassGroupTeacher>("class_group_teachers", {
    class_group_id: classGroupId,
  });

export const getClassTimetable = (classGroupId: string) =>
  queryView<TimetableEntry>("class_timetable", { class_group_id: classGroupId });

export const getTeacherTimetable = (teacherId: string) =>
  queryView<TimetableEntry>("teacher_timetable", { teacher_id: teacherId });

export const getStudentTimetable = (studentId: string) =>
  queryView<TimetableEntry>("student_timetable", { student_id: studentId });

export const getTeacherWorkload = (academicYearId: string) =>
  queryView<TeacherWorkloadSummary>("teacher_workload_summary", {
    academic_year_id: academicYearId,
  });

export const getStudentFinancialBalance = (
  studentId: string,
  academicYearId: string,
) =>
  queryView<StudentFinancialBalance>("student_financial_balances", {
    student_id: studentId,
    academic_year_id: academicYearId,
  });

export const getAcademicYearHistory = (schoolId: string) =>
  queryView<AcademicYearHistory>("academic_year_history", {
    school_id: schoolId,
  });

export const getAssessmentPeriodHistory = (academicYearId: string) =>
  queryView<AssessmentPeriodHistory>("assessment_period_history", {
    academic_year_id: academicYearId,
  });


function sanitizeSearchTerm(value: string) {
  return value
    .replace(/[\\%_]/g, "")
    .replace(/[(),]/g, " ")
    .trim()
    .slice(0, 80);
}

export async function searchStudentDirectory(search = "") {
  const { supabase } = await requireAuthenticatedServerClient();
  const term = sanitizeSearchTerm(search);
  try {
    let query = supabase.from("student_directory").select("*").order("full_name", { ascending: true });
    if (term) query = query.or(`full_name.ilike.%${term}%,school_number.ilike.%${term}%`);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as import("@sige/contracts").StudentDirectory[];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function searchEnrollmentDirectory(search = "") {
  const { supabase } = await requireAuthenticatedServerClient();
  const term = sanitizeSearchTerm(search);
  try {
    let query = supabase.from("enrollment_directory").select("*").order("enrolled_on", { ascending: false });
    if (term) query = query.or(`student_name.ilike.%${term}%,school_number.ilike.%${term}%,class_name.ilike.%${term}%`);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as import("@sige/contracts").EnrollmentDirectory[];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function searchTeacherDirectory(search = "") {
  const { supabase } = await requireAuthenticatedServerClient();
  const term = sanitizeSearchTerm(search);
  try {
    let query = supabase.from("teacher_directory").select("*").order("full_name", { ascending: true });
    if (term) query = query.or(`full_name.ilike.%${term}%,employee_code.ilike.%${term}%`);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as import("@sige/contracts").TeacherDirectory[];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function searchGuardianDirectory(search = "") {
  const { supabase } = await requireAuthenticatedServerClient();
  const term = sanitizeSearchTerm(search);
  try {
    let query = supabase.from("guardian_directory").select("*").order("full_name", { ascending: true });
    if (term) query = query.or(`full_name.ilike.%${term}%,identity_number.ilike.%${term}%`);
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as import("@sige/contracts").GuardianDirectory[];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}


export async function getAcademicYearOptions() {
  const { supabase } = await requireAuthenticatedServerClient();
  try {
    const { data, error } = await supabase
      .from("academic_years")
      .select("id,label,status,starts_on,ends_on")
      .order("starts_on", { ascending: false });
    if (error) throw error;
    return data ?? [];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function getGradeLevelOptions() {
  const { supabase } = await requireAuthenticatedServerClient();
  try {
    const { data, error } = await supabase
      .from("grade_levels")
      .select("id,name,code,ordinal,academic_cycle_id")
      .eq("active", true)
      .order("ordinal", { ascending: true });
    if (error) throw error;
    return data ?? [];
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function getEnrollment(enrollmentId: string) {
  const { supabase } = await requireAuthenticatedServerClient();
  try {
    const { data, error } = await supabase
      .from("enrollment_directory")
      .select("*")
      .eq("id", enrollmentId)
      .maybeSingle();
    if (error) throw error;
    return data as import("@sige/contracts").EnrollmentDirectory | null;
  } catch (error) {
    throw normalizeSigeError(error);
  }
}

export async function getClassGroup(classGroupId: string) {
  const { supabase } = await requireAuthenticatedServerClient();
  try {
    const { data, error } = await supabase
      .from("class_group_directory")
      .select("*")
      .eq("id", classGroupId)
      .maybeSingle();
    if (error) throw error;
    return data as import("@sige/contracts").ClassGroupDirectory | null;
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
