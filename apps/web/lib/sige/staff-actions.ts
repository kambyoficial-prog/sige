"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { getCurrentAccessContext } from "@/lib/sige/access";

const schema=z.object({
  schoolId:z.string().uuid(),
  fullName:z.string().trim().min(2).max(160),
  employeeCode:z.string().trim().min(2).max(40),
  jobTitle:z.string().trim().min(2).max(120),
  email:z.string().trim().email().max(160),
  phone:z.string().trim().max(40).optional()
});

export async function createSecretariatStaffAction(input:unknown){
  const parsed=schema.safeParse(input);
  if(!parsed.success)return {ok:false as const,code:"INVALID_ARGUMENT" as const};

  const access=await getCurrentAccessContext();
  if(!access.memberships.some(m=>m.school_id===parsed.data.schoolId&&m.permissions.includes("staff.manage")))
    return {ok:false as const,code:"FORBIDDEN" as const};

  const admin=createSupabaseAdminClient(),p=parsed.data,today=new Date().toISOString().slice(0,10);
  let personId:string|undefined, staffId:string|undefined, accountId:string|undefined, authUserId:string|undefined;

  try{
    const {data:person,error:pe}=await admin.from("people").insert({
      full_name:p.fullName,email:p.email,phone:p.phone??null
    }).select("id").single();
    if(pe||!person)throw new Error("PERSON_CREATE_FAILED");
    personId=person.id;

    const {data:staff,error:se}=await admin.from("staff_members").insert({
      school_id:p.schoolId,person_id:person.id,employee_code:p.employeeCode,status:"ACTIVE"
    }).select("id").single();
    if(se||!staff)throw new Error("STAFF_CREATE_FAILED");
    staffId=staff.id;

    const {error:ee}=await admin.from("employments").insert({
      school_id:p.schoolId,person_id:person.id,employee_code:p.employeeCode,
      job_title:p.jobTitle,starts_on:today,active:true
    });
    if(ee)throw new Error("EMPLOYMENT_CREATE_FAILED");

    // The Auth invite is intentionally the only non-transactional boundary.
    // No role is encoded in user_metadata; authorization comes from app_accounts/account_roles.
    const {data:invite,error:ie}=await admin.auth.admin.inviteUserByEmail(p.email);
    if(ie||!invite.user)throw new Error("ACCOUNT_INVITE_FAILED");
    authUserId=invite.user.id;

    const {data:account,error:ae}=await admin.from("app_accounts").insert({
      auth_user_id:invite.user.id,person_id:person.id,active:true,
      first_access_required:true,credential_issued_at:new Date().toISOString()
    }).select("id").single();
    if(ae||!account)throw new Error("ACCOUNT_CREATE_FAILED");
    accountId=account.id;

    const {data:role}=await admin.from("roles").select("id").eq("code","SECRETARIAT").single();
    if(!role)throw new Error("ROLE_NOT_CONFIGURED");

    const {error:re}=await admin.from("account_roles").insert({
      app_account_id:account.id,role_id:role.id,school_id:p.schoolId,
      active:true,starts_on:today
    });
    if(re)throw new Error("ROLE_ASSIGN_FAILED");

    revalidatePath("/funcionarios");
    return {ok:true as const,result:{staffId,accountId,email:p.email}};
  }catch(error){
    if(authUserId){
      await admin.auth.admin.deleteUser(authUserId).catch(()=>undefined);
    }
    if(accountId)await admin.from("app_accounts").delete().eq("id",accountId);
    if(staffId)await admin.from("staff_members").delete().eq("id",staffId);
    if(personId){
      await admin.from("employments").delete().eq("person_id",personId);
      await admin.from("people").delete().eq("id",personId);
    }
    const code=error instanceof Error?error.message:"ACCOUNT_PROVISIONING_FAILED";
    return {ok:false as const,code};
  }
}
