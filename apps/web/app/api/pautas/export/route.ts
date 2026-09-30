import { NextRequest, NextResponse } from "next/server";
import ExcelJS from "exceljs";
import {
  getAcademicResultPauta,
  getAcademicYearOptions,
  getAssessmentGradebook,
  getClassGroupDirectory,
  getClassGroupStudents,
  getCourseOfferings,
  getStudentDirectory,
} from "@/lib/sige/queries";
import { requireAuthenticatedServerClient } from "@/lib/supabase/server";
import { OFFICIAL_PAUTA_SUBJECTS, classifyExamCall, normalizePautaGroup } from "@/lib/sige/official-pauta";

export const runtime = "nodejs";

const border = { style: "thin" as const, color: { argb: "FF000000" } };
const borders = { top: border, left: border, bottom: border, right: border };
const center = { horizontal: "center" as const, vertical: "middle" as const, wrapText: true };
const headerFill = { type: "pattern" as const, pattern: "solid" as const, fgColor: { argb: "FFD9E1F2" } };

function numberOrNull(value: number | string | null | undefined) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function safeName(value: string) {
  return value.replace(/[^a-zA-Z0-9_-]+/g, "_").slice(0, 80);
}

export async function GET(request: NextRequest) {
  const classGroupId = request.nextUrl.searchParams.get("classGroupId");
  if (!classGroupId) return NextResponse.json({ error: "classGroupId é obrigatório." }, { status: 400 });

  const years = await getAcademicYearOptions();
  const year = years.find((item) => item.status === "OPEN") ?? years[0];
  if (!year) return NextResponse.json({ error: "Não existe ano lectivo disponível." }, { status: 404 });

  const classes = await getClassGroupDirectory(year.id);
  const selectedClass = classes.find((item) => item.id === classGroupId);
  if (!selectedClass) return NextResponse.json({ error: "Turma não encontrada." }, { status: 404 });

  const { supabase } = await requireAuthenticatedServerClient();
  const { data: pathways } = await supabase
    .from("academic_pathways")
    .select("id,name,code")
    .eq("active", true)
    .order("code");

  const pathwayMap = new Map((pathways ?? []).map((pathway) => [pathway.id, pathway.name]));
  const pathwayName = selectedClass.pathway_id ? pathwayMap.get(selectedClass.pathway_id) ?? null : null;
  const group = normalizePautaGroup(pathwayName);

  const [gradebook, publishedResults, students, roster, courseOfferings, schoolResult] = await Promise.all([
    getAssessmentGradebook({ class_group_id: classGroupId }),
    getAcademicResultPauta({ class_group_id: classGroupId }),
    getStudentDirectory(),
    getClassGroupStudents(classGroupId),
    getCourseOfferings(classGroupId),
    supabase.from("schools").select("name").eq("active", true).order("created_at").limit(1).maybeSingle(),
  ]);

  const officialSubjects = group
    ? OFFICIAL_PAUTA_SUBJECTS[group]
    : courseOfferings.map((item) => ({ code: item.subject_code, name: item.subject_name, span: 3 as const }));

  const subjectByCode = new Map(courseOfferings.map((item) => [item.subject_code, item]));
  const subjects = officialSubjects.map((subject) => ({
    ...subject,
    courseOfferingId: subjectByCode.get(subject.code)?.id ?? null,
  }));

  const studentMap = new Map(students.map((student) => [student.id, student]));
  const resultMap = new Map(
    publishedResults.map((result) => [
      result.student_id + ":" + result.course_offering_id + ":" + result.result_type,
      result,
    ]),
  );
  const examRows = gradebook.filter((row) => row.type === "EXAM");

  const workbook = new ExcelJS.Workbook();
  workbook.creator = "SIGE";
  workbook.created = new Date();
  workbook.modified = new Date();
  workbook.calcProperties = { fullCalcOnLoad: true, forceFullCalc: true, calcMode: "auto" };

  const sheet = workbook.addWorksheet(group === "B" ? "Pauta01" : "PAUTA1", {
    views: [{ showGridLines: false }],
    pageSetup: {
      orientation: "landscape",
      paperSize: 9,
      fitToWidth: 1,
      fitToHeight: 0,
      horizontalDpi: 300,
      verticalDpi: 300,
    },
    pageMargins: { left: 0.2, right: 0.2, top: 0.25, bottom: 0.25, header: 0.1, footer: 0.1 },
  });

  [5, 15, 34, 8, 12].forEach((width, index) => {
    sheet.getColumn(index + 1).width = width;
  });

  sheet.mergeCells("A1:AO1");
  sheet.getCell("A1").value = "REPÚBLICA DE MOÇAMBIQUE";
  sheet.getCell("A1").font = { bold: true, size: 11 };
  sheet.getCell("A1").alignment = center;

  sheet.mergeCells("A2:AO2");
  sheet.getCell("A2").value = "Província";
  sheet.getCell("A2").alignment = center;

  sheet.mergeCells("A3:AO3");
  sheet.getCell("A3").value = "Direcção Provincial da Educação";
  sheet.getCell("A3").alignment = center;

  sheet.mergeCells("A4:AO4");
  sheet.getCell("A4").value = schoolResult.data?.name ?? "Escola Secundária";
  sheet.getCell("A4").font = { bold: true, size: 12 };
  sheet.getCell("A4").alignment = center;

  sheet.mergeCells("A5:AO5");
  sheet.getCell("A5").value = "12.ª CLASSE · " + (pathwayName ?? "OPÇÃO");
  sheet.getCell("A5").font = { bold: true };
  sheet.getCell("A5").alignment = center;

  sheet.mergeCells("A6:AO6");
  sheet.getCell("A6").value = "PAUTA DE EXAME · " + year.label;
  sheet.getCell("A6").font = { bold: true };
  sheet.getCell("A6").alignment = center;

  sheet.mergeCells("A7:AO7");
  sheet.getCell("A7").value = "Turma: " + (selectedClass.name ?? selectedClass.section_code);
  sheet.getCell("A7").alignment = center;

  const headerRow = 9;
  const subHeaderRow = 10;
  const firstDataRow = 11;
  const lastDataRow = firstDataRow + Math.max(roster.length, 1) - 1;

  ["N.º", "Código", "Nome do Aluno", "Género", "Turma"].forEach((label, index) => {
    sheet.mergeCells(headerRow, index + 1, subHeaderRow, index + 1);
    sheet.getCell(headerRow, index + 1).value = label;
  });

  let column = 6;
  const coreColumns: Array<{ code: string; frequency: number; exam: number; average: number }> = [];
  const specialColumns: Array<{ code: string; column: number }> = [];

  for (const subject of subjects) {
    if (subject.span === 3) {
      const start = column;
      sheet.mergeCells(headerRow, start, headerRow, start + 2);
      sheet.getCell(headerRow, start).value = subject.name;
      sheet.getCell(headerRow, start).fill = headerFill;
      sheet.getCell(headerRow, start).alignment = center;
      ["Frequênc.", "1ª/2ª ch", "Média"].forEach((label, offset) => {
        sheet.getCell(subHeaderRow, start + offset).value = label;
        sheet.getCell(subHeaderRow, start + offset).fill = headerFill;
        sheet.getCell(subHeaderRow, start + offset).alignment = center;
      });
      coreColumns.push({ code: subject.code, frequency: start, exam: start + 1, average: start + 2 });
      column += 3;
    } else {
      sheet.mergeCells(headerRow, column, subHeaderRow, column);
      sheet.getCell(headerRow, column).value = subject.name;
      sheet.getCell(headerRow, column).fill = headerFill;
      sheet.getCell(headerRow, column).alignment = center;
      specialColumns.push({ code: subject.code, column });
      column += 1;
    }
  }

  const averageColumn = column;
  const approvedColumn = column + 1;
  const failedColumn = column + 2;

  sheet.mergeCells(headerRow, averageColumn, subHeaderRow, averageColumn);
  sheet.getCell(headerRow, averageColumn).value = "Média";
  sheet.mergeCells(headerRow, approvedColumn, headerRow, failedColumn);
  sheet.getCell(headerRow, approvedColumn).value = "RESULTADO FINAL";
  sheet.getCell(subHeaderRow, approvedColumn).value = "Aprovado";
  sheet.getCell(subHeaderRow, failedColumn).value = "Reprovado";

  for (let c = 1; c <= failedColumn; c += 1) {
    for (let r = headerRow; r <= subHeaderRow; r += 1) {
      sheet.getCell(r, c).border = borders;
      sheet.getCell(r, c).alignment = center;
      sheet.getCell(r, c).font = { bold: true, size: 8 };
    }
  }

  for (let index = 0; index < roster.length; index += 1) {
    const rosterStudent = roster[index];
    const rowNumber = firstDataRow + index;
    const person = studentMap.get(rosterStudent.student_id);
    const rawGender = (person?.gender ?? "").toUpperCase();
    const gender = rawGender.startsWith("F") ? "M" : "H";

    sheet.getCell(rowNumber, 1).value = index + 1;
    sheet.getCell(rowNumber, 2).value = rosterStudent.school_number;
    sheet.getCell(rowNumber, 3).value = rosterStudent.student_name;
    sheet.getCell(rowNumber, 4).value = gender;
    sheet.getCell(rowNumber, 5).value = selectedClass.name ?? selectedClass.section_code;

    for (let c = 1; c <= failedColumn; c += 1) {
      sheet.getCell(rowNumber, c).border = borders;
      sheet.getCell(rowNumber, c).alignment = center;
      sheet.getCell(rowNumber, c).font = { size: 8 };
    }

    const studentExamRows = examRows.filter((item) => item.student_id === rosterStudent.student_id);
    const getExam = (courseOfferingId: string | null) => {
      if (!courseOfferingId) return { first: null, second: null };
      const candidates = studentExamRows.filter((item) => item.course_offering_id === courseOfferingId);
      const first = candidates.find((item) => classifyExamCall(item.title) === 1);
      const second = candidates.find((item) => classifyExamCall(item.title) === 2);
      return { first: numberOrNull(first?.raw_score), second: numberOrNull(second?.raw_score) };
    };

    const averageCells: string[] = [];

    for (const subject of coreColumns) {
      const source = subjects.find((item) => item.code === subject.code);
      const exam = getExam(source?.courseOfferingId ?? null);
      const frequencyResult = resultMap.get(
        rosterStudent.student_id + ":" + (source?.courseOfferingId ?? "") + ":FREQUENCY",
      );

      sheet.getCell(rowNumber, subject.frequency).value = numberOrNull(frequencyResult?.display_value);
      sheet.getCell(rowNumber, subject.exam).value = exam.first ?? exam.second;

      const frequencyAddress = sheet.getCell(rowNumber, subject.frequency).address;
      const examAddress = sheet.getCell(rowNumber, subject.exam).address;
      const averageAddress = sheet.getCell(rowNumber, subject.average).address;

      sheet.getCell(rowNumber, subject.average).value = {
        formula: 'IF(OR(' + frequencyAddress + '="",' + examAddress + '=""),"",ROUND((2*' + frequencyAddress + '+' + examAddress + ')/3,0))',
      };
      averageCells.push(averageAddress);
    }

    for (const special of specialColumns) {
      const source = subjects.find((item) => item.code === special.code);
      const result = resultMap.get(
        rosterStudent.student_id + ":" + (source?.courseOfferingId ?? "") + ":FINAL",
      );
      sheet.getCell(rowNumber, special.column).value = numberOrNull(result?.display_value);
    }

    const averageFormula = averageCells.length
      ? 'IFERROR(ROUND(AVERAGE(' + averageCells.join(",") + '),0),"")'
      : '""';

    sheet.getCell(rowNumber, averageColumn).value = { formula: averageFormula };

    const averageAddress = sheet.getCell(rowNumber, averageColumn).address;
    const failedFormula = averageCells
      .map((cell) => 'AND(ISNUMBER(' + cell + '),' + cell + '<10)')
      .join(",");

    sheet.getCell(rowNumber, approvedColumn).value = {
      formula: 'IF(' + averageAddress + '="","",IF(OR(' + failedFormula + '),' + '""' + ',IF(' + averageAddress + '>=10,"X","")))'
    };
    sheet.getCell(rowNumber, failedColumn).value = {
      formula: 'IF(' + averageAddress + '="","",IF(OR(' + failedFormula + '),"X",""))'
    };
  }

  const mapStart = lastDataRow + 4;
  sheet.mergeCells(mapStart, 1, mapStart, failedColumn);
  sheet.getCell(mapStart, 1).value = "MAPA DE APROVEITAMENTO PEDAGÓGICO";
  sheet.getCell(mapStart, 1).font = { bold: true, size: 10 };
  sheet.getCell(mapStart, 1).alignment = center;

  const mapHeader = mapStart + 2;
  sheet.getCell(mapHeader, 1).value = "Escala de Notas";
  sheet.getCell(mapHeader, 2).value = "Gen.";

  let mapColumn = 3;
  const mapSubjectColumns = new Map<string, { first: number; second: number; total: number }>();

  for (const subject of coreColumns) {
    const source = subjects.find((item) => item.code === subject.code)!;
    mapSubjectColumns.set(subject.code, { first: mapColumn, second: mapColumn + 1, total: mapColumn + 2 });
    sheet.mergeCells(mapHeader, mapColumn, mapHeader, mapColumn + 2);
    sheet.getCell(mapHeader, mapColumn).value = source.name;
    sheet.getCell(mapHeader, mapColumn).fill = headerFill;
    sheet.getCell(mapHeader, mapColumn).alignment = center;
    sheet.getCell(mapHeader + 1, mapColumn).value = "1ª Ch";
    sheet.getCell(mapHeader + 1, mapColumn + 1).value = "2ª Ch";
    sheet.getCell(mapHeader + 1, mapColumn + 2).value = "Total";
    mapColumn += 3;
  }

  for (let c = 1; c < mapColumn; c += 1) {
    sheet.getCell(mapHeader, c).border = borders;
    sheet.getCell(mapHeader, c).alignment = center;
    sheet.getCell(mapHeader, c).font = { bold: true, size: 8 };
    sheet.getCell(mapHeader + 1, c).border = borders;
    sheet.getCell(mapHeader + 1, c).alignment = center;
    sheet.getCell(mapHeader + 1, c).font = { bold: true, size: 8 };
  }

  const bands = [
    ["0 - 5.9", 0, 5.9],
    ["6 - 8.9", 6, 8.9],
    ["9 - 13.9", 9, 13.9],
    ["14 - 16.9", 14, 16.9],
    ["17 - 20", 17, 20],
  ] as const;

  let row = mapHeader + 2;

  for (const [label, min, max] of bands) {
    for (const gender of ["M", "H", "HM"] as const) {
      sheet.getCell(row, 1).value = gender === "M" ? label : "";
      sheet.getCell(row, 2).value = gender;

      for (const subject of coreColumns) {
        const cols = mapSubjectColumns.get(subject.code)!;
        const examColumn = sheet.getColumn(subject.exam).letter;
        const genderClause = gender === "HM"
          ? ""
          : '$D$' + firstDataRow + ':$D$' + lastDataRow + ',"' + gender + '",';

        const firstFormula = gender === "HM"
          ? 'COUNTIFS(' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=' + min + '",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=' + max + '")'
          : 'COUNTIFS($D$' + firstDataRow + ':$D$' + lastDataRow + ',"' + gender + '",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=' + min + '",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=' + max + '")';

        sheet.getCell(row, cols.first).value = { formula: firstFormula };
        sheet.getCell(row, cols.second).value = { formula: "0" };
        sheet.getCell(row, cols.total).value = { formula: sheet.getCell(row, cols.first).address + "+" + sheet.getCell(row, cols.second).address };
      }

      for (let c = 1; c < mapColumn; c += 1) {
        sheet.getCell(row, c).border = borders;
        sheet.getCell(row, c).alignment = center;
        sheet.getCell(row, c).font = { size: 8 };
      }

      row += 1;
    }
  }

  const metrics = ["Previstos", "Avaliados", "Positivos", "% dos Positivos"] as const;

  for (const metric of metrics) {
    for (const gender of ["M", "H", "HM"] as const) {
      sheet.getCell(row, 1).value = metric;
      sheet.getCell(row, 2).value = gender;

      for (const subject of coreColumns) {
        const cols = mapSubjectColumns.get(subject.code)!;
        const frequencyColumn = sheet.getColumn(subject.frequency).letter;
        const examColumn = sheet.getColumn(subject.exam).letter;

        const frequencyFormula = gender === "HM"
          ? 'COUNTIFS(' + frequencyColumn + firstDataRow + ':' + frequencyColumn + lastDataRow + ',"<=20")'
          : 'COUNTIFS($D$' + firstDataRow + ':$D$' + lastDataRow + ',"' + gender + '",' + frequencyColumn + firstDataRow + ':' + frequencyColumn + lastDataRow + ',"<=20")';

        const evaluatedFormula = gender === "HM"
          ? 'COUNTIFS(' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=0",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=20")'
          : 'COUNTIFS($D$' + firstDataRow + ':$D$' + lastDataRow + ',"' + gender + '",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=0",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=20")';

        const positiveFormula = gender === "HM"
          ? 'COUNTIFS(' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=10",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=20")'
          : 'COUNTIFS($D$' + firstDataRow + ':$D$' + lastDataRow + ',"' + gender + '",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',">=10",' + examColumn + firstDataRow + ':' + examColumn + lastDataRow + ',"<=20")';

        if (metric === "Previstos") {
          sheet.getCell(row, cols.first).value = { formula: frequencyFormula };
          sheet.getCell(row, cols.second).value = { formula: "0" };
          sheet.getCell(row, cols.total).value = { formula: sheet.getCell(row, cols.first).address + "+" + sheet.getCell(row, cols.second).address };
        } else if (metric === "Avaliados") {
          sheet.getCell(row, cols.first).value = { formula: evaluatedFormula };
          sheet.getCell(row, cols.second).value = { formula: "0" };
          sheet.getCell(row, cols.total).value = { formula: sheet.getCell(row, cols.first).address + "+" + sheet.getCell(row, cols.second).address };
        } else if (metric === "Positivos") {
          sheet.getCell(row, cols.first).value = { formula: positiveFormula };
          sheet.getCell(row, cols.second).value = { formula: "0" };
          sheet.getCell(row, cols.total).value = { formula: sheet.getCell(row, cols.first).address + "+" + sheet.getCell(row, cols.second).address };
        } else {
          sheet.getCell(row, cols.first).value = {
            formula: 'IFERROR(' + sheet.getCell(row - 6, cols.first).address + '/' + sheet.getCell(row - 3, cols.first).address + '*100,"")',
          };
          sheet.getCell(row, cols.second).value = { formula: '""' };
          sheet.getCell(row, cols.total).value = { formula: sheet.getCell(row, cols.first).address };
        }
      }

      for (let c = 1; c < mapColumn; c += 1) {
        sheet.getCell(row, c).border = borders;
        sheet.getCell(row, c).alignment = center;
        sheet.getCell(row, c).font = { size: 8 };
      }

      row += 1;
    }
  }

  const summaryStart = row + 2;
  sheet.getCell(summaryStart, 1).value = "RESUMO GLOBAL";
  sheet.getCell(summaryStart, 1).font = { bold: true };
  ["M", "H", "HM"].forEach((gender, index) => {
    const summaryRow = summaryStart + 1 + index;
    sheet.getCell(summaryRow, 1).value = gender;
    sheet.getCell(summaryRow, 2).value = { formula: gender === "HM"
      ? 'COUNTA(D' + firstDataRow + ':D' + lastDataRow + ')'
      : 'COUNTIF(D' + firstDataRow + ':D' + lastDataRow + ',"' + gender + '")' };
    sheet.getCell(summaryRow, 3).value = { formula: gender === "HM"
      ? 'COUNT(AM' + firstDataRow + ':AM' + lastDataRow + ')'
      : 'COUNTIFS(D' + firstDataRow + ':D' + lastDataRow + ',"' + gender + '",AM' + firstDataRow + ':AM' + lastDataRow + ',">=0")' };
    sheet.getCell(summaryRow, 4).value = { formula: gender === "HM"
      ? 'COUNTIF(AM' + firstDataRow + ':AM' + lastDataRow + ',">=10")'
      : 'COUNTIFS(D' + firstDataRow + ':D' + lastDataRow + ',"' + gender + '",AM' + firstDataRow + ':AM' + lastDataRow + ',">=10")' };
    sheet.getCell(summaryRow, 5).value = { formula: 'IFERROR(D' + summaryRow + '/C' + summaryRow + '*100,"")' };
    ["Inscritos", "Examinados", "Positivos", "% Positivos"].forEach((label, index) => {
      if (index === 0) sheet.getCell(summaryStart, index + 2).value = label;
    });
    for (let c = 1; c <= 5; c += 1) {
      sheet.getCell(summaryRow, c).border = borders;
      sheet.getCell(summaryRow, c).alignment = center;
    }
  });

  sheet.printArea = "A1:" + sheet.getColumn(mapColumn - 1).letter + (summaryStart + 4);
  sheet.headerFooter.oddFooter.center.text = "SIGE · Pauta Oficial";
  sheet.headerFooter.oddFooter.right.text = "Página &P de &N";

  const buffer = await workbook.xlsx.writeBuffer();
  const filename = "Pauta_" + (group ?? "12") + "_" + safeName(selectedClass.name ?? selectedClass.section_code) + "_" + safeName(year.label) + ".xlsx";

  return new NextResponse(Buffer.from(buffer), {
    status: 200,
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": "attachment; filename="" + filename + """,
      "Cache-Control": "no-store",
    },
  });
}
