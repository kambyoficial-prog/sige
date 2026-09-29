import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
async function view<T>(name:string, params:Record<string,string|undefined>={}) {
  const { supabase }=await requireAuthenticatedServerClient(); let q=supabase.from(name).select("*");
  for(const [k,v] of Object.entries(params)) if(v) q=q.eq(k,v);
  const {data,error}=await q; if(error) throw error; return (data??[]) as T[];
}
export type ReportRow=Record<string,unknown>;
export const getReportDemographics=()=>view<ReportRow>("report_student_demographics");
export const getReportEnrollmentStatus=(academicYearId?:string)=>view<ReportRow>("report_enrollment_status",{academic_year_id:academicYearId});
export const getReportEnrollmentGrade=(academicYearId?:string)=>view<ReportRow>("report_enrollment_grade",{academic_year_id:academicYearId});
export const getReportClassCapacity=(academicYearId?:string)=>view<ReportRow>("report_class_capacity",{academic_year_id:academicYearId});
export const getReportFinanceSummary=(academicYearId?:string)=>view<ReportRow>("report_finance_summary",{academic_year_id:academicYearId});
export const getReportAcademicOutcomes=(academicYearId?:string)=>view<ReportRow>("report_academic_outcomes",{academic_year_id:academicYearId});
export const getReportEnrollmentExits=(academicYearId?:string)=>view<ReportRow>("report_enrollment_exits",{academic_year_id:academicYearId});
export const getReportClassTransfers=(academicYearId?:string)=>view<ReportRow>("report_class_transfers",{academic_year_id:academicYearId});
