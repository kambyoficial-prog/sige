import "server-only";

import {
  type CurrentAccessContext,
  normalizeSigeError,
} from "@sige/contracts";

import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

export async function getCurrentAccessContext(): Promise<CurrentAccessContext> {
  const { supabase } = await requireAuthenticatedServerClient();

  try {
    const { data, error } = await supabase.rpc("current_access_context");

    if (error) throw error;

    return data as CurrentAccessContext;
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
