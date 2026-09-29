"use server";

import { z } from "zod";
import { SigeApplicationError } from "@sige/contracts";
import { executeCommand } from "@/lib/sige/commands";

const createClassSchema=z.object({
  academicYearId:z.string().uuid(),
  gradeLevelId:z.string().uuid(),
  sectionCode:z.string().trim().min(1).max(20),
  pathwayId:z.string().uuid().optional().or(z.literal("")),
  shift:z.enum(["MORNING","AFTERNOON","EVENING","FULL_DAY"]).optional().or(z.literal("")),
  capacity:z.coerce.number().int().positive().optional(),
  name:z.string().trim().max(100).optional(),
});
const generateSchema=z.object({classGroupId:z.string().uuid()});
const teacherSchema=z.object({courseOfferingId:z.string().uuid(),teacherId:z.string().uuid(),startsOn:z.string().min(10),endsOn:z.string().optional()});
const directorSchema=z.object({classGroupId:z.string().uuid(),teacherId:z.string().uuid(),startsOn:z.string().min(10),endsOn:z.string().optional(),reason:z.string().max(240).optional()});

type Result={ok:true;result:unknown}|{ok:false;code:string};
function failure(error:unknown):Result{return{ok:false,code:error instanceof SigeApplicationError?error.code:"UNKNOWN"}}

export async function createClassGroupAction(input:unknown):Promise<Result>{
  const p=createClassSchema.safeParse(input); if(!p.success)return{ok:false,code:"INVALID_ARGUMENT"};
  try{return{ok:true,result:await executeCommand("create_class_group",{...p.data,pathwayId:p.data.pathwayId||undefined,shift:p.data.shift||undefined,idempotencyKey:crypto.randomUUID()})}}catch(e){return failure(e)}
}
export async function generateClassOfferingsAction(input:unknown):Promise<Result>{
  const p=generateSchema.safeParse(input); if(!p.success)return{ok:false,code:"INVALID_ARGUMENT"};
  try{return{ok:true,result:await executeCommand("generate_class_offerings",{...p.data,idempotencyKey:crypto.randomUUID()})}}catch(e){return failure(e)}
}
export async function assignTeacherAction(input:unknown):Promise<Result>{
  const p=teacherSchema.safeParse(input); if(!p.success)return{ok:false,code:"INVALID_ARGUMENT"};
  try{return{ok:true,result:await executeCommand("assign_teacher_to_offering",{...p.data,idempotencyKey:crypto.randomUUID()})}}catch(e){return failure(e)}
}
export async function assignDirectorAction(input:unknown):Promise<Result>{
  const p=directorSchema.safeParse(input); if(!p.success)return{ok:false,code:"INVALID_ARGUMENT"};
  try{return{ok:true,result:await executeCommand("assign_class_group_director",{...p.data,idempotencyKey:crypto.randomUUID()})}}catch(e){return failure(e)}
}
