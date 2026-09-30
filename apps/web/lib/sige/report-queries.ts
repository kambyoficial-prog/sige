import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
async function report<T>(name:string, academicYearId?:string) {
  const { supabase } = await requireAuthenticatedServerClient();
  const { data, error } = await supabase.rpc("get_report_rows", {
    p_report: name,
    p_academic_year_id: academicYearId ?? null,
  });
  if (error) throw error;
  return (Array.isArray(data) ? data : []) as T[];
}
export type ReportRow=Record<string,unknown>;
export const getReportDemographics=()=>report<ReportRow>("report_student_demographics");
export const getReportEnrollmentStatus=(academicYearId?:string)=>report<ReportRow>("report_enrollment_status",academicYearId);
export const getReportEnrollmentGrade=(academicYearId?:string)=>report<ReportRow>("report_enrollment_grade",academicYearId);
export const getReportClassCapacity=(academicYearId?:string)=>report<ReportRow>("report_class_capacity",academicYearId);
export const getReportFinanceSummary=(academicYearId?:string)=>report<ReportRow>("report_finance_summary",academicYearId);
export const getReportAcademicOutcomes=(academicYearId?:string)=>report<ReportRow>("report_academic_outcomes",academicYearId);
export const getReportEnrollmentExits=(academicYearId?:string)=>report<ReportRow>("report_enrollment_exits",academicYearId);
export const getReportClassTransfers=(academicYearId?:string)=>report<ReportRow>("report_class_transfers",academicYearId);