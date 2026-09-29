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
