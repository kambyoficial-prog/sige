"use server";

import { z } from "zod";
import { normalizeSigeError } from "@sige/contracts";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const createSchema=z.object({
  paymentId:z.string().uuid(),
  originalFilename:z.string().min(1).max(255),
  contentType:z.enum(["application/pdf","image/jpeg","image/png"]),
  byteSize:z.number().int().positive().max(10485760),
});

export async function createPaymentProofUploadAction(input:unknown){
  try{
    const value=createSchema.parse(input);
    const supabase=await createSupabaseServerClient();
    const {data,error}=await supabase.rpc("create_payment_proof_upload",{
      p_payment_id:value.paymentId,
      p_original_filename:value.originalFilename,
      p_content_type:value.contentType,
      p_byte_size:value.byteSize,
      p_idempotency_key:crypto.randomUUID(),
      p_request_hash:null,
    });
    if(error) throw error;
    const payload=data as {proof_id:string;bucket:string;path:string};
    const signed=await supabase.storage.from(payload.bucket).createSignedUploadUrl(payload.path);
    if(signed.error) throw signed.error;
    return {proofId:payload.proof_id,bucket:payload.bucket,path:payload.path,token:signed.data.token};
  }catch(error){throw normalizeSigeError(error);}
}

export async function finalizePaymentProofAction(input:unknown){
  try{
    const proofId=z.string().uuid().parse(input);
    const supabase=await createSupabaseServerClient();
    const {data,error}=await supabase.rpc("finalize_payment_proof",{
      p_proof_id:proofId,p_idempotency_key:crypto.randomUUID(),p_request_hash:null,
    });
    if(error) throw error;
    return data;
  }catch(error){throw normalizeSigeError(error);}
}

export async function verifyPaymentProofAction(input:unknown){
  try{
    const value=z.object({
      proofId:z.string().uuid(),
      status:z.enum(["VERIFIED","REJECTED"]),
      rejectionReason:z.string().max(1000).optional(),
    }).parse(input);
    const supabase=await createSupabaseServerClient();
    const {data,error}=await supabase.rpc("verify_payment_proof",{
      p_proof_id:value.proofId,p_status:value.status,p_rejection_reason:value.rejectionReason??null,
      p_idempotency_key:crypto.randomUUID(),p_request_hash:null,
    });
    if(error) throw error;
    return data;
  }catch(error){throw normalizeSigeError(error);}
}

export async function getPaymentProofSignedUrlAction(input:unknown){
  try{
    const proofId=z.string().uuid().parse(input);
    const supabase=await createSupabaseServerClient();
    const {data,error}=await supabase.rpc("get_payment_proof",{p_proof_id:proofId});
    if(error) throw error;
    if(!data) throw new Error("PAYMENT_PROOF_NOT_FOUND");
    const proof=data as {bucket:string;path:string};
    const signed=await supabase.storage.from(proof.bucket).createSignedUrl(proof.path,300);
    if(signed.error) throw signed.error;
    return {url:signed.data.signedUrl};
  }catch(error){throw normalizeSigeError(error);}
}
