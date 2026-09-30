import "server-only";

import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

export async function getStudentFinancialPortal() {
  const { supabase } = await requireAuthenticatedServerClient();
  const { data, error } = await supabase.rpc("get_student_financial_portal");
  if (error) throw error;
  return (data ?? {
    academic_year_id: null,
    academic_year: null,
    charges: [],
    payment_instructions: [],
    payments: [],
  }) as {
    academic_year_id: string | null;
    academic_year: { id: string; label: string; starts_on: string; ends_on: string } | null;
    charges: Array<{
      id: string; fee_type: string | null; description: string | null; amount: number;
      due_on: string; status: string; paid_amount: number; remaining_amount: number;
    }>;
    payment_instructions: Array<{
      id: string; label: string; bank_name: string | null; account_name: string | null;
      account_number: string | null; nib: string | null; iban: string | null; branch: string | null;
      payment_reference_template: string | null; instructions: string | null;
    }>;
    payments: Array<{
      id: string; amount: number; method: string; status: string; paid_at: string;
      confirmed_at: string | null; external_reference: string | null; receipt_number: string | null;
    }>;
  };
}
