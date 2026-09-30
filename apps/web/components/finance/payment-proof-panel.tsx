"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import {
  createPaymentProofUploadAction,
  finalizePaymentProofAction,
  getPaymentProofSignedUrlAction,
  verifyPaymentProofAction,
} from "@/lib/sige/payment-proof-actions";

type Proof={
  id:string;
  original_filename:string;
  content_type:string;
  byte_size:number;
  status:string;
  rejection_reason?:string|null;
};

const statusLabel:Record<string,string>={
  UPLOADING:"A carregar",
  READY:"Por verificar",
  VERIFIED:"Verificado",
  REJECTED:"Rejeitado",
};

export function PaymentProofPanel({paymentId,proofs}:{paymentId:string;proofs:Proof[]}){
  const router=useRouter();
  const inputRef=useRef<HTMLInputElement>(null);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState<string|null>(null);

  async function upload(){
    const file=inputRef.current?.files?.[0];
    if(!file) return;
    setBusy(true); setError(null);
    try{
      const allowed=["application/pdf","image/jpeg","image/png"];
      if(!allowed.includes(file.type)) throw new Error("Tipo de ficheiro não permitido.");
      if(file.size>10*1024*1024) throw new Error("O comprovativo excede 10 MB.");
      const signed=await createPaymentProofUploadAction({
        paymentId,originalFilename:file.name,contentType:file.type,byteSize:file.size,
      });
      const supabase=createSupabaseBrowserClient();
      const result=await supabase.storage.from(signed.bucket).uploadToSignedUrl(signed.path,signed.token,file,{
        contentType:file.type,
      });
      if(result.error) throw result.error;
      await finalizePaymentProofAction(signed.proofId);
      if(inputRef.current) inputRef.current.value="";
      router.refresh();
    }catch(e){setError(e instanceof Error?e.message:"Não foi possível carregar o comprovativo.");}
    finally{setBusy(false);}
  }

  async function verify(proofId:string,status:"VERIFIED"|"REJECTED"){
    setBusy(true); setError(null);
    try{
      let rejectionReason:string|undefined;
      if(status==="REJECTED"){
        rejectionReason=window.prompt("Motivo da rejeição do comprovativo:")?.trim();
        if(!rejectionReason) return;
      }
      await verifyPaymentProofAction({proofId,status,rejectionReason});
      router.refresh();
    }catch(e){setError(e instanceof Error?e.message:"Não foi possível atualizar o comprovativo.");}
    finally{setBusy(false);}
  }

  async function openProof(proofId:string){
    setBusy(true); setError(null);
    try{
      const result=await getPaymentProofSignedUrlAction(proofId);
      window.open(result.url,"_blank","noopener,noreferrer");
    }catch(e){setError(e instanceof Error?e.message:"Não foi possível abrir o comprovativo.");}
    finally{setBusy(false);}
  }

  return <div className="space-y-3 rounded-lg border bg-muted/20 p-4">
    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <div className="text-sm font-medium">Comprovativo</div>
        <div className="text-xs text-muted-foreground">PDF, JPG ou PNG até 10 MB. O ficheiro permanece privado.</div>
      </div>
      <div className="flex items-center gap-2">
        <input ref={inputRef} type="file" accept=".pdf,image/jpeg,image/png,application/pdf" className="max-w-[230px] text-sm" disabled={busy}/>
        <Button type="button" size="sm" onClick={upload} disabled={busy}>Carregar</Button>
      </div>
    </div>
    {proofs.length>0&&<div className="space-y-2">
      {proofs.map(proof=><div key={proof.id} className="flex flex-col gap-2 rounded-md border bg-background p-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <div className="truncate text-sm font-medium">{proof.original_filename}</div>
          <div className="text-xs text-muted-foreground">{statusLabel[proof.status]??proof.status} · {(Number(proof.byte_size)/1024/1024).toFixed(2)} MB</div>
          {proof.rejection_reason&&<div className="mt-1 text-xs text-destructive">{proof.rejection_reason}</div>}
        </div>
        <div className="flex flex-wrap gap-2">
          <Button type="button" size="sm" variant="outline" onClick={()=>openProof(proof.id)} disabled={busy}>Abrir</Button>
          {proof.status==="READY"&&<>
            <Button type="button" size="sm" onClick={()=>verify(proof.id,"VERIFIED")} disabled={busy}>Validar</Button>
            <Button type="button" size="sm" variant="destructive" onClick={()=>verify(proof.id,"REJECTED")} disabled={busy}>Rejeitar</Button>
          </>}
        </div>
      </div>)}
    </div>}
    {error&&<div role="alert" className="text-sm text-destructive">{error}</div>}
  </div>;
}
