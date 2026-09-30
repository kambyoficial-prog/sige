import "server-only";

import {
  type CurrentAccessContext,
  normalizeSigeError,
} from "@sige/contracts";

import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

export async function getCurrentAccessContext(): Promise<CurrentAccessContext> {
  try {
    // Normalize both session and database authorization failures at this boundary.
    const { supabase } = await requireAuthenticatedServerClient();
    const { data, error } = await supabase.rpc("current_access_context");

    if (error) throw error;

    return data as CurrentAccessContext;
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
