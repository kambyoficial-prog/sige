"use client";

import Link from "next/link";
import type { ColumnDef } from "@tanstack/react-table";
import { Badge } from "@/components/ui/badge";
import { DataTable, type DataTableFeatures } from "@/components/ui/data-table";

type DirectoryKind = "students" | "teachers" | "guardians" | "enrollments" | "classes" | "profile";

export function DirectoryTable({ kind, data, emptyTitle, emptyDescription }: { kind: DirectoryKind; data: any[]; emptyTitle?: string; emptyDescription?: string }) {
  const columns = (() => {
    switch (kind) {
      case "students":
        return [
          { accessorKey: "school_number", header: "N.º" },
          { accessorKey: "full_name", header: "Aluno", cell: ({ row }: any) => <Link className="font-medium hover:underline" href={`/alunos/${row.original.id}`}>{row.original.full_name}</Link> },
          { accessorKey: "gender", header: "Sexo", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "class_name", header: "Turma", cell: ({ getValue }: any) => getValue<string>() || "Sem turma" },
          { accessorKey: "enrollment_status", header: "Matrícula", cell: ({ getValue }: any) => <Badge variant="secondary">{getValue<string>() || "Sem matrícula"}</Badge> },
        ] as any[];
      case "teachers":
        return [
          { accessorKey: "employee_code", header: "Código" },
          { accessorKey: "full_name", header: "Professor", cell: ({ row }: any) => <Link className="font-medium hover:underline" href={`/professores/${row.original.id}`}>{row.original.full_name}</Link> },
          { accessorKey: "phone", header: "Telefone", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "email", header: "Email", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "status", header: "Estado" },
        ] as any[];
      case "guardians":
        return [
          { accessorKey: "full_name", header: "Encarregado" },
          { accessorKey: "relationship", header: "Relação", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "phone", header: "Telefone", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "student_count", header: "Alunos" },
        ] as any[];
      case "enrollments":
        return [
          { accessorKey: "school_number", header: "N.º" },
          { accessorKey: "student_name", header: "Aluno", cell: ({ row }: any) => <Link className="font-medium hover:underline" href={`/matriculas/${row.original.id}`}>{row.original.student_name}</Link> },
          { accessorKey: "academic_year_label", header: "Ano letivo" },
          { accessorKey: "grade_level_name", header: "Classe" },
          { accessorKey: "class_name", header: "Turma", cell: ({ getValue }: any) => getValue<string>() || "Sem turma" },
          { accessorKey: "status", header: "Estado", cell: ({ getValue }: any) => <Badge variant="secondary">{getValue<string>()}</Badge> },
        ] as any[];
      case "classes":
        return [
          { accessorKey: "academic_year_label", header: "Ano letivo" },
          { accessorKey: "grade_level_name", header: "Classe" },
          { accessorKey: "name", header: "Turma", cell: ({ row }: any) => <Link href={`/turmas/${row.original.id}`} className="font-medium hover:underline">{row.original.name || row.original.section_code}</Link> },
          { accessorKey: "shift", header: "Turno", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "student_count", header: "Alunos" },
          { accessorKey: "director_teacher_name", header: "Diretor de turma", cell: ({ getValue }: any) => getValue<string>() || "—" },
          { accessorKey: "status", header: "Estado", cell: ({ getValue }: any) => <Badge variant="secondary">{getValue<string>()}</Badge> },
        ] as any[];
      case "profile":
        return [
          { accessorKey: "school_name", header: "Escola" },
          { accessorKey: "school_code", header: "Código" },
          { accessorKey: "roles", header: "Funções" },
          { accessorKey: "permissions", header: "Permissões" },
        ] as any[];
    }
  })();

  return <DataTable columns={columns as never} data={data as never} emptyTitle={emptyTitle} emptyDescription={emptyDescription} />;
}
