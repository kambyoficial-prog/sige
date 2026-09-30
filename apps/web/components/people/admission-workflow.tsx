"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { registerStudentAction, createGuardianAction } from "@/lib/sige/people-actions";
import { enrollStudentAction, placeStudentAction } from "@/lib/sige/enrollment-actions";
import { errorMessage } from "@/lib/sige/presentation";

type Year = { id: string; label: string; status: string };
type Grade = { id: string; name: string; code: string; academic_cycle_id: string };
type Pathway = { id: string; code: string; name: string; academic_cycle_id: string };
type ClassGroup = {
  id: string;
  academic_year_id: string;
  grade_level_id: string;
  section_code: string;
  name: string | null;
  pathway_id: string | null;
  pathway_name: string | null;
  status: string;
  shift: string | null;
  capacity: number | null;
  student_count: number;
};

type GuardianDraft = {
  fullName: string;
  relationship: string;
  occupation: string;
  identityNumber: string;
  address: string;
  phone: string;
  isPrimary: boolean;
};

const documentTypes = [
  ["BI", "Bilhete de Identidade"],
  ["BI_TALAO", "Talão de BI"],
  ["BIRTH_CERTIFICATE", "Certidão / assento de nascimento"],
  ["PERSONAL_ID", "Cédula pessoal"],
  ["PASSPORT", "Passaporte"],
  ["DIRE", "DIRE"],
  ["OTHER", "Outro documento"],
] as const;

const studentSchema = z.object({
  firstName: z.string().trim().min(2, "Indique o nome do aluno."),
  lastName: z.string().trim().optional(),
  gender: z.enum(["M", "F"]).optional().or(z.literal("")),
  birthDate: z.string().optional(),
  documentType: z.string().optional(),
  documentValue: z.string().trim().max(120).optional(),
  phone: z.string().trim().max(40).optional(),
  email: z.string().email("Email inválido.").or(z.literal("")),
  address: z.string().trim().max(240).optional(),
});

type Props = {
  school: { id: string; name: string; code: string };
  years: Year[];
  grades: Grade[];
  pathways: Pathway[];
  classes: ClassGroup[];
};

const emptyGuardian = (): GuardianDraft => ({
  fullName: "",
  relationship: "",
  occupation: "",
  identityNumber: "",
  address: "",
  phone: "",
  isPrimary: false,
});

export function AdmissionWorkflow({ school, years, grades, pathways, classes }: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState(0);
  const [studentId, setStudentId] = useState<string | null>(null);
  const [studentNumber, setStudentNumber] = useState<string | null>(null);
  const [enrollmentId, setEnrollmentId] = useState<string | null>(null);
  const [placementDone, setPlacementDone] = useState(false);

  const [student, setStudent] = useState({
    firstName: "",
    lastName: "",
    gender: "" as "" | "M" | "F",
    birthDate: "",
    documentType: "",
    documentValue: "",
    phone: "",
    email: "",
    address: "",
  });

  const [guardians, setGuardians] = useState<[GuardianDraft, GuardianDraft]>([
    emptyGuardian(),
    emptyGuardian(),
  ]);

  const [academicYearId, setAcademicYearId] = useState(
    years.find((year) => year.status === "OPEN")?.id ?? years[0]?.id ?? "",
  );
  const [gradeLevelId, setGradeLevelId] = useState("");
  const [pathwayId, setPathwayId] = useState("");
  const [classGroupId, setClassGroupId] = useState("");
  const [entryType, setEntryType] = useState<"INITIAL" | "TRANSFER_IN" | "REENTRY">("INITIAL");
  const [enrolledOn, setEnrolledOn] = useState(new Date().toISOString().slice(0, 10));

  const selectedGrade = grades.find((grade) => grade.id === gradeLevelId);
  const availablePathways = pathways.filter(
    (pathway) => pathway.academic_cycle_id === selectedGrade?.academic_cycle_id,
  );

  const availableClasses = useMemo(
    () =>
      classes.filter(
        (item) =>
          item.academic_year_id === academicYearId &&
          item.grade_level_id === gradeLevelId &&
          item.status === "OPEN" &&
          (!pathwayId || item.pathway_id === pathwayId),
      ),
    [academicYearId, gradeLevelId, pathwayId, classes],
  );

  function updateGuardian(index: 0 | 1, patch: Partial<GuardianDraft>) {
    setGuardians((current) => {
      const next = [...current] as [GuardianDraft, GuardianDraft];
      next[index] = { ...next[index], ...patch };
      return next;
    });
  }

  function createStudent() {
    const parsed = studentSchema.safeParse(student);
    if (!parsed.success) {
      toast.error(parsed.error.issues[0]?.message ?? "Verifique os dados do aluno.");
      return;
    }

    startTransition(async () => {
      const result = await registerStudentAction({
        schoolId: school.id,
        ...student,
        gender: student.gender || undefined,
        documentType: student.documentType || undefined,
        documentValue: student.documentValue || undefined,
        email: student.email || "",
      });

      if (!result.ok) {
        toast.error(errorMessage(result.code as never));
        return;
      }

      const payload = result.result as { student_id?: string; school_number?: string };
      if (!payload.student_id) {
        toast.error("O registo foi processado, mas o SIGE não devolveu o aluno.");
        return;
      }

      setStudentId(payload.student_id);
      setStudentNumber(payload.school_number ?? null);
      setStep(1);
      toast.success("Aluno registado.");
    });
  }

  function saveFamilyAndContinue() {
    if (!studentId) return;

    const items = guardians.filter((guardian) => guardian.fullName.trim());
    if (!items.length) {
      setStep(2);
      return;
    }

    startTransition(async () => {
      for (const guardian of items) {
        const result = await createGuardianAction({
          schoolId: school.id,
          studentId,
          fullName: guardian.fullName.trim(),
          relationship: guardian.relationship.trim() || undefined,
          occupation: guardian.occupation.trim() || undefined,
          identityNumber: guardian.identityNumber.trim() || undefined,
          address: guardian.address.trim() || undefined,
          phone: guardian.phone.trim() || undefined,
          isPrimary: guardian.isPrimary,
        });

        if (!result.ok) {
          toast.error(errorMessage(result.code as never));
          return;
        }
      }

      setStep(2);
      toast.success("Filiação registada.");
    });
  }

  function createEnrollment(withPlacement: boolean) {
    if (!studentId || !academicYearId || !gradeLevelId) {
      toast.error("Selecione o ano e a classe.");
      return;
    }

    if (withPlacement && !classGroupId) {
      toast.error("Selecione a turma.");
      return;
    }

    startTransition(async () => {
      const enrollment = await enrollStudentAction({
        studentId,
        academicYearId,
        gradeLevelId,
        pathwayId: pathwayId || undefined,
        entryType,
        enrolledOn,
      });

      if (!enrollment.ok) {
        toast.error(errorMessage(enrollment.code as never));
        return;
      }

      const payload = enrollment.result as { enrollment_id?: string };
      if (!payload.enrollment_id) {
        toast.error("A matrícula foi processada, mas o SIGE não devolveu a matrícula.");
        return;
      }

      setEnrollmentId(payload.enrollment_id);

      if (!withPlacement) {
        setPlacementDone(false);
        setStep(3);
        toast.success("Matrícula criada. A turma pode ser atribuída depois.");
        return;
      }

      const placement = await placeStudentAction({
        enrollmentId: payload.enrollment_id,
        classGroupId,
        startsOn: enrolledOn,
      });

      if (!placement.ok) {
        setPlacementDone(false);
        setStep(3);
        toast.warning("Matrícula criada. A turma ficou por atribuir.");
        return;
      }

      setPlacementDone(true);
      setStep(3);
      toast.success("Aluno matriculado e colocado na turma.");
    });
  }

  function finish() {
    router.push(studentId ? "/alunos/" + studentId : "/alunos");
  }

  const steps = ["Aluno", "Filiação", "Matrícula", "Concluído"];

  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card">
      <div className="border-b border-border px-5 py-4 sm:px-7">
        <div className="flex items-center gap-2">
          {steps.map((label, index) => (
            <div key={label} className="flex min-w-0 flex-1 items-center gap-2">
              <div
                className={
                  "grid size-7 shrink-0 place-items-center rounded-full text-xs font-medium " +
                  (index <= step ? "bg-foreground text-background" : "bg-muted text-muted-foreground")
                }
              >
                {index < step ? "✓" : index + 1}
              </div>
              <span className={"truncate text-sm " + (index === step ? "font-medium" : "text-muted-foreground")}>
                {label}
              </span>
              {index < steps.length - 1 ? <div className="hidden h-px flex-1 bg-border sm:block" /> : null}
            </div>
          ))}
        </div>
      </div>

      <div className="p-5 sm:p-7">
        {step === 0 && (
          <section className="space-y-6">
            <div>
              <h2 className="text-lg font-semibold">Dados do aluno</h2>
              <p className="text-sm text-muted-foreground">
                Registe o essencial. O número do aluno é atribuído automaticamente.
              </p>
            </div>

            <div className="grid gap-5 md:grid-cols-2">
              <FormField id="firstName" label="Nome(s)" required>
                <Input autoFocus value={student.firstName} onChange={(e) => setStudent({ ...student, firstName: e.target.value })} />
              </FormField>
              <FormField id="lastName" label="Apelido">
                <Input value={student.lastName} onChange={(e) => setStudent({ ...student, lastName: e.target.value })} />
              </FormField>
              <FormField id="gender" label="Sexo">
                <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={student.gender} onChange={(e) => setStudent({ ...student, gender: e.target.value as "" | "M" | "F" })}>
                  <option value="">Não indicado</option>
                  <option value="M">Masculino</option>
                  <option value="F">Feminino</option>
                </select>
              </FormField>
              <FormField id="birthDate" label="Data de nascimento">
                <Input type="date" value={student.birthDate} onChange={(e) => setStudent({ ...student, birthDate: e.target.value })} />
              </FormField>
              <FormField id="documentType" label="Documento">
                <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={student.documentType} onChange={(e) => setStudent({ ...student, documentType: e.target.value })}>
                  <option value="">Não apresentado</option>
                  {documentTypes.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </FormField>
              <FormField id="documentValue" label="Número / referência">
                <Input value={student.documentValue} onChange={(e) => setStudent({ ...student, documentValue: e.target.value })} />
              </FormField>
              <FormField id="phone" label="Telefone">
                <Input value={student.phone} onChange={(e) => setStudent({ ...student, phone: e.target.value })} />
              </FormField>
              <FormField id="email" label="Email">
                <Input type="email" value={student.email} onChange={(e) => setStudent({ ...student, email: e.target.value })} />
              </FormField>
              <div className="md:col-span-2">
                <FormField id="address" label="Residência atual">
                  <Textarea value={student.address} onChange={(e) => setStudent({ ...student, address: e.target.value })} rows={3} />
                </FormField>
              </div>
            </div>

            <div className="flex justify-end border-t border-border pt-5">
              <Button type="button" disabled={pending} onClick={createStudent}>
                {pending ? "A guardar…" : "Continuar"}
              </Button>
            </div>
          </section>
        )}

        {step === 1 && (
          <section className="space-y-6">
            <div>
              <h2 className="text-lg font-semibold">Filiação e encarregado</h2>
              <p className="text-sm text-muted-foreground">
                Pai, mãe ou outro encarregado podem ser registados sem abrir outro processo.
              </p>
            </div>

            <div className="grid gap-5 lg:grid-cols-2">
              {([0, 1] as const).map((index) => (
                <div key={index} className="rounded-xl border border-border p-5">
                  <div className="mb-4 flex items-center justify-between">
                    <div className="font-medium">{index === 0 ? "Pai / encarregado" : "Mãe / encarregada"}</div>
                    <label className="flex items-center gap-2 text-xs text-muted-foreground">
                      <input type="checkbox" checked={guardians[index].isPrimary} onChange={(e) => updateGuardian(index, { isPrimary: e.target.checked })} />
                      Principal
                    </label>
                  </div>

                  <div className="grid gap-4 sm:grid-cols-2">
                    <FormField id={"guardian-" + index + "-name"} label="Nome completo">
                      <Input value={guardians[index].fullName} onChange={(e) => updateGuardian(index, { fullName: e.target.value })} />
                    </FormField>
                    <FormField id={"guardian-" + index + "-relationship"} label="Parentesco">
                      <Input value={guardians[index].relationship} onChange={(e) => updateGuardian(index, { relationship: e.target.value })} placeholder={index === 0 ? "Pai" : "Mãe"} />
                    </FormField>
                    <FormField id={"guardian-" + index + "-occupation"} label="Profissão">
                      <Input value={guardians[index].occupation} onChange={(e) => updateGuardian(index, { occupation: e.target.value })} />
                    </FormField>
                    <FormField id={"guardian-" + index + "-id"} label="BI / documento">
                      <Input value={guardians[index].identityNumber} onChange={(e) => updateGuardian(index, { identityNumber: e.target.value })} />
                    </FormField>
                    <FormField id={"guardian-" + index + "-phone"} label="Telefone">
                      <Input value={guardians[index].phone} onChange={(e) => updateGuardian(index, { phone: e.target.value })} />
                    </FormField>
                    <div className="sm:col-span-2">
                      <FormField id={"guardian-" + index + "-address"} label="Residência">
                        <Textarea value={guardians[index].address} onChange={(e) => updateGuardian(index, { address: e.target.value })} rows={2} />
                      </FormField>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex items-center justify-between border-t border-border pt-5">
              <Button type="button" variant="outline" onClick={() => setStep(0)}>Anterior</Button>
              <div className="flex gap-2">
                <Button type="button" variant="ghost" disabled={pending} onClick={() => setStep(2)}>Continuar sem filiação</Button>
                <Button type="button" disabled={pending} onClick={saveFamilyAndContinue}>{pending ? "A guardar…" : "Continuar"}</Button>
              </div>
            </div>
          </section>
        )}

        {step === 2 && (
          <section className="space-y-6">
            <div>
              <h2 className="text-lg font-semibold">Matrícula e turma</h2>
              <p className="text-sm text-muted-foreground">
                O ano aberto é sugerido automaticamente. A lista de turmas é filtrada pela classe e pelo grupo.
              </p>
            </div>

            <div className="grid gap-5 md:grid-cols-2">
              <FormField id="academicYear" label="Ano letivo" required>
                <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={academicYearId} onChange={(e) => { setAcademicYearId(e.target.value); setClassGroupId(""); }}>
                  {years.map((year) => <option key={year.id} value={year.id}>{year.label}{year.status === "OPEN" ? " · Atual" : ""}</option>)}
                </select>
              </FormField>

              <FormField id="grade" label="Classe" required>
                <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={gradeLevelId} onChange={(e) => { setGradeLevelId(e.target.value); setPathwayId(""); setClassGroupId(""); }}>
                  <option value="">Selecionar classe</option>
                  {grades.map((grade) => <option key={grade.id} value={grade.id}>{grade.name}</option>)}
                </select>
              </FormField>

              {availablePathways.length > 0 ? (
                <FormField id="pathway" label="Grupo / área" required>
                  <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={pathwayId} onChange={(e) => { setPathwayId(e.target.value); setClassGroupId(""); }}>
                    <option value="">Selecionar grupo</option>
                    {availablePathways.map((pathway) => <option key={pathway.id} value={pathway.id}>{pathway.code} · {pathway.name}</option>)}
                  </select>
                </FormField>
              ) : null}

              <FormField id="entryType" label="Entrada" required>
                <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={entryType} onChange={(e) => setEntryType(e.target.value as typeof entryType)}>
                  <option value="INITIAL">Inicial</option>
                  <option value="TRANSFER_IN">Transferência de entrada</option>
                  <option value="REENTRY">Reingresso</option>
                </select>
              </FormField>

              <FormField id="enrolledOn" label="Data da matrícula" required>
                <Input type="date" value={enrolledOn} onChange={(e) => setEnrolledOn(e.target.value)} />
              </FormField>

              <div className="md:col-span-2">
                <FormField id="classGroup" label="Turma">
                  <select className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={classGroupId} onChange={(e) => setClassGroupId(e.target.value)} disabled={!gradeLevelId || (availablePathways.length > 0 && !pathwayId)}>
                    <option value="">{gradeLevelId ? "Selecionar turma" : "Escolha primeiro a classe"}</option>
                    {availableClasses.map((item) => (
                      <option key={item.id} value={item.id}>
                        {(item.name || item.section_code) + (item.shift ? " · " + item.shift : "") + " · " + item.student_count + (item.capacity ? "/" + item.capacity : "")}
                      </option>
                    ))}
                  </select>
                  {gradeLevelId && !availableClasses.length ? (
                    <p className="mt-2 text-sm text-muted-foreground">Não há turma compatível aberta. A matrícula pode ser concluída e a turma atribuída depois.</p>
                  ) : null}
                </FormField>
              </div>
            </div>

            <div className="flex items-center justify-between border-t border-border pt-5">
              <Button type="button" variant="outline" onClick={() => setStep(1)}>Anterior</Button>
              <div className="flex gap-2">
                <Button type="button" variant="ghost" disabled={pending || !gradeLevelId} onClick={() => createEnrollment(false)}>
                  Matrícula sem turma
                </Button>
                <Button type="button" disabled={pending || !gradeLevelId || !classGroupId} onClick={() => createEnrollment(true)}>
                  {pending ? "A concluir…" : "Concluir processo"}
                </Button>
              </div>
            </div>
          </section>
        )}

        {step === 3 && (
          <section className="space-y-6">
            <div className="rounded-2xl bg-muted/40 p-6">
              <p className="text-sm text-muted-foreground">Processo concluído</p>
              <h2 className="mt-1 text-2xl font-semibold">{student.firstName} {student.lastName}</h2>
              <p className="mt-2 text-sm text-muted-foreground">
                {studentNumber ? "Número do aluno: " + studentNumber + " · " : ""}
                {placementDone ? "matrícula criada e turma atribuída." : "matrícula criada; a turma pode ser atribuída depois."}
              </p>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              <div className="rounded-xl border border-border p-4">
                <p className="text-xs text-muted-foreground">Aluno</p>
                <p className="mt-1 font-medium">Registado</p>
              </div>
              <div className="rounded-xl border border-border p-4">
                <p className="text-xs text-muted-foreground">Matrícula</p>
                <p className="mt-1 font-medium">{enrollmentId ? "Criada" : "Pendente"}</p>
              </div>
              <div className="rounded-xl border border-border p-4">
                <p className="text-xs text-muted-foreground">Turma</p>
                <p className="mt-1 font-medium">{placementDone ? "Atribuída" : "Por atribuir"}</p>
              </div>
            </div>

            <div className="flex justify-end border-t border-border pt-5">
              <Button type="button" onClick={finish}>Abrir aluno</Button>
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
