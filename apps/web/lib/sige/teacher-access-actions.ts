"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { getCurrentAccessContext } from "@/lib/sige/access";

const schema=z.object({
  schoolId:z.string().uuid(),
  teacherId:z.string().uuid(),
  email:z.string().trim().email().max(160)
});

export async function activateTeacherAccessAction(input:unknown){
  const parsed=schema.safeParse(input);
  if(!parsed.success)return {ok:false as const,code:"INVALID_ARGUMENT" as const};

  const access=await getCurrentAccessContext();
  if(!access.memberships.some(m=>m.school_id===parsed.data.schoolId&&m.permissions.includes("teacher.manage")))
    return {ok:false as const,code:"FORBIDDEN" as const};

  const admin=createSupabaseAdminClient();

  const {data:teacher,error:te}=await admin
    .from("teachers")
    .select("id,person_id,school_id,status")
    .eq("id",parsed.data.teacherId)
    .eq("school_id",parsed.data.schoolId)
    .single();

  if(te||!teacher)return {ok:false as const,code:"TEACHER_NOT_FOUND" as const};
  if(teacher.status!=="ACTIVE")return {ok:false as const,code:"TEACHER_NOT_ACTIVE" as const};

  const {data:existing}=await admin
    .from("app_accounts")
    .select("id,active")
    .eq("person_id",teacher.person_id)
    .maybeSingle();

  if(existing?.id)return {ok:false as const,code:"ACCOUNT_ALREADY_EXISTS" as const};

  const {data:person,error:pe}=await admin
    .from("people")
    .select("id,email")
    .eq("id",teacher.person_id)
    .single();

  if(pe||!person)return {ok:false as const,code:"PERSON_NOT_FOUND" as const};

  // A teacher can be registered without institutional email. Access is a separate action
  // and requires an actual reachable email supplied by the school.
  if(person.email && person.email.toLowerCase()!==parsed.data.email.toLowerCase())
    return {ok:false as const,code:"EMAIL_CONFLICT" as const};

  if(!person.email){
    const {error:ue}=await admin.from("people").update({email:parsed.data.email}).eq("id",person.id);
    if(ue)return {ok:false as const,code:"PERSON_EMAIL_UPDATE_FAILED" as const};
  }

  let authUserId:string|undefined,accountId:string|undefined;
  try{
    const {data:invite,error:ie}=await admin.auth.admin.inviteUserByEmail(parsed.data.email);
    if(ie||!invite.user)throw new Error("ACCOUNT_INVITE_FAILED");
    authUserId=invite.user.id;

    const {data:account,error:ae}=await admin.from("app_accounts").insert({
      auth_user_id:authUserId,
      person_id:teacher.person_id,
      active:true,
      first_access_required:true,
      credential_issued_at:new Date().toISOString()
    }).select("id").single();
    if(ae||!account)throw new Error("ACCOUNT_CREATE_FAILED");
    accountId=account.id;

    const {data:role}=await admin.from("roles").select("id").eq("code","TEACHER").single();
    if(!role)throw new Error("ROLE_NOT_CONFIGURED");

    const {error:re}=await admin.from("account_roles").insert({
      app_account_id:account.id,
      role_id:role.id,
      school_id:teacher.school_id,
      active:true,
      starts_on:new Date().toISOString().slice(0,10)
    });
    if(re)throw new Error("ROLE_ASSIGN_FAILED");

    revalidatePath("/professores");
    return {ok:true as const,result:{teacherId:teacher.id,accountId,email:parsed.data.email}};
  }catch(error){
    if(authUserId)await admin.auth.admin.deleteUser(authUserId).catch(()=>undefined);
    if(accountId)await admin.from("app_accounts").delete().eq("id",accountId);
    const code=error instanceof Error?error.message:"ACCOUNT_PROVISIONING_FAILED";
    return {ok:false as const,code};
  }
}
