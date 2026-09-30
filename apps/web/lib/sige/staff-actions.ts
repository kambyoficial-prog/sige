"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { getCurrentAccessContext } from "@/lib/sige/access";

const schema=z.object({schoolId:z.string().uuid(),fullName:z.string().trim().min(2).max(160),employeeCode:z.string().trim().min(2).max(40),jobTitle:z.string().trim().min(2).max(120),email:z.string().trim().email().max(160),phone:z.string().trim().max(40).optional()});
export async function createSecretariatStaffAction(input:unknown){
 const parsed=schema.safeParse(input); if(!parsed.success)return {ok:false as const,code:"INVALID_ARGUMENT" as const};
 const access=await getCurrentAccessContext(); if(!access.memberships.some(m=>m.school_id===parsed.data.schoolId&&m.permissions.includes("staff.manage")))return {ok:false as const,code:"FORBIDDEN" as const};
 const admin=createSupabaseAdminClient(); const supabase=await createSupabaseServerClient();
 const p=parsed.data;
 const {data:person,error:pe}=await admin.from("people").insert({full_name:p.fullName,email:p.email,phone:p.phone??null}).select("id").single();
 if(pe)return {ok:false as const,code:"PERSON_CREATE_FAILED" as const};
 const {data:staff,error:se}=await admin.from("staff_members").insert({school_id:p.schoolId,person_id:person.id,employee_code:p.employeeCode,status:"ACTIVE"}).select("id").single();
 if(se)return {ok:false as const,code:"STAFF_CREATE_FAILED" as const};
 const {error:ee}=await admin.from("employments").insert({school_id:p.schoolId,person_id:person.id,employee_code:p.employeeCode,job_title:p.jobTitle,starts_on:new Date().toISOString().slice(0,10),active:true});
 if(ee)return {ok:false as const,code:"EMPLOYMENT_CREATE_FAILED" as const};
 const {data:invite,error:ie}=await admin.auth.admin.inviteUserByEmail(p.email,{data:{sige_role:"SECRETARIAT"}});
 if(ie||!invite.user)return {ok:false as const,code:"ACCOUNT_INVITE_FAILED" as const};
 const {data:account,error:ae}=await admin.from("app_accounts").insert({auth_user_id:invite.user.id,person_id:person.id,active:true,first_access_required:true,credential_issued_at:new Date().toISOString()}).select("id").single();
 if(ae)return {ok:false as const,code:"ACCOUNT_CREATE_FAILED" as const};
 const {data:role}=await admin.from("roles").select("id").eq("code","SECRETARIAT").single();
 if(!role)return {ok:false as const,code:"ROLE_NOT_CONFIGURED" as const};
 const {error:re}=await admin.from("account_roles").insert({app_account_id:account.id,role_id:role.id,school_id:p.schoolId,active:true,starts_on:new Date().toISOString().slice(0,10)});
 if(re)return {ok:false as const,code:"ROLE_ASSIGN_FAILED" as const};
 await supabase.from("people").select("id").eq("id",person.id).maybeSingle();
 revalidatePath("/funcionarios"); revalidatePath("/pessoas");
 return {ok:true as const,result:{staffId:staff.id,accountId:account.id,email:p.email}};
}
