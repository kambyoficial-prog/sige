import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const allowed = new Set([
  "report_student_demographics",
  "report_enrollment_status",
  "report_enrollment_grade",
  "report_class_capacity",
  "report_finance_summary",
  "report_academic_outcomes",
  "report_enrollment_exits",
  "report_class_transfers",
]);

function csv(rows: Record<string, unknown>[]) {
  if (!rows.length) return "";
  const keys = Object.keys(rows[0]);
  const esc = (v: unknown) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  return [keys.map(esc).join(","), ...rows.map(r => keys.map(k => esc(r[k])).join(","))].join("\n");
}

export async function GET(request: NextRequest, context: { params: Promise<{ report: string }> }) {
  const { report } = await context.params;
  if (!allowed.has(report)) return new NextResponse("REPORT_NOT_FOUND", { status: 404 });
  const academicYearId = request.nextUrl.searchParams.get("academic_year_id");
  const supabase = await createClient();
  let query = supabase.from(report).select("*");
  if (academicYearId && report !== "report_student_demographics") query = query.eq("academic_year_id", academicYearId);
  const { data, error } = await query;
  if (error) return new NextResponse("REPORT_READ_FAILED", { status: 500 });
  return new NextResponse(csv((data ?? []) as Record<string, unknown>[]), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${report}.csv"`,
      "Cache-Control": "private, no-store",
    },
  });
}
