import "server-only";

import {
  type CommandName,
  type SigeCommandInputMap,
  normalizeSigeError,
} from "@sige/contracts";

import { requireAuthenticatedServerClient } from "@/lib/supabase/server";

type RpcArgs = Record<string, unknown>;

const RPC_NAMES: Record<CommandName, string> = {
  register_student: "register_student",
  create_guardian: "create_guardian",
  assign_class_group_director: "assign_class_group_director",
  enroll_student: "enroll_student",
  place_student_in_class: "place_student_in_class",
  record_payment: "record_payment",
  confirm_payment: "confirm_payment",
  allocate_payment: "allocate_payment",
  reverse_payment: "reverse_payment",
  issue_receipt: "issue_receipt",
  create_assessment: "create_assessment",
  save_assessment_result: "save_assessment_result",
  publish_assessment: "publish_assessment",
  correct_published_result: "correct_published_result",
  calculate_trimester_result: "calculate_trimester_result",
  homologate_academic_result: "homologate_academic_result",
  publish_academic_result: "publish_academic_result",
  calculate_frequency_result: "calculate_frequency_result",
  calculate_final_result: "calculate_final_result",
  open_academic_year: "open_academic_year",
  close_academic_year: "close_academic_year",
  initialize_assessment_periods: "initialize_assessment_periods",
  close_assessment_period: "close_assessment_period",
  create_class_group: "create_class_group",
  update_class_group: "update_class_group",
  close_class_group: "close_class_group",
  generate_class_offerings: "generate_class_offerings",
  assign_teacher_to_offering: "assign_teacher_to_offering",
  transfer_student_class: "transfer_student_class",
  configure_curriculum_subject: "configure_curriculum_subject",
  create_room: "create_room",
  create_schedule_period: "create_schedule_period",
  upsert_school_calendar_day: "upsert_school_calendar_day",
  create_schedule_entry: "create_schedule_entry",
  set_schedule_entry_status: "set_schedule_entry_status",
};

function toRpcArgs<Name extends CommandName>(
  name: Name,
  input: SigeCommandInputMap[Name],
): RpcArgs {
  const i = input as Record<string, unknown>;

  const common = {
    p_idempotency_key: i.idempotencyKey,
    p_request_hash: i.requestHash ?? null,
  };

  const map: Record<CommandName, RpcArgs> = {
    assign_class_group_director: {
      p_class_group_id: i.classGroupId,
      p_teacher_id: i.teacherId,
      p_starts_on: i.startsOn,
      p_ends_on: i.endsOn ?? null,
      p_reason: i.reason ?? null,
      ...common,
    },
    register_student: {
      p_school_id: i.schoolId,
      p_school_number: i.schoolNumber,
      p_full_name: i.fullName,
      p_first_name: i.firstName ?? null,
      p_last_name: i.lastName ?? null,
      p_gender: i.gender ?? null,
      p_birth_date: i.birthDate ?? null,
      p_national_id: i.nationalId ?? null,
      p_phone: i.phone ?? null,
      p_email: i.email ?? null,
      p_address: i.address ?? null,
      p_admission_date: i.admissionDate ?? undefined,
      ...common,
    },
    create_guardian: {
      p_school_id: i.schoolId,
      p_student_id: i.studentId,
      p_full_name: i.fullName,
      p_relationship: i.relationship ?? null,
      p_occupation: i.occupation ?? null,
      p_identity_number: i.identityNumber ?? null,
      p_address: i.address ?? null,
      p_phone: i.phone ?? null,
      p_gender: i.gender ?? null,
      p_birth_date: i.birthDate ?? null,
      p_national_id: i.nationalId ?? null,
      p_is_primary: i.isPrimary ?? false,
      p_lives_with_student: i.livesWithStudent ?? null,
      ...common,
    },
    enroll_student: {
      p_student_id: i.studentId,
      p_academic_year_id: i.academicYearId,
      p_grade_level_id: i.gradeLevelId,
      p_entry_type: i.entryType ?? "INITIAL",
      p_enrolled_on: i.enrolledOn ?? undefined,
      ...common,
    },
    place_student_in_class: {
      p_enrollment_id: i.enrollmentId,
      p_class_group_id: i.classGroupId,
      p_starts_on: i.startsOn ?? undefined,
      p_ends_on: i.endsOn ?? null,
      p_reason: i.reason ?? null,
      ...common,
    },
    record_payment: {
      p_student_id: i.studentId,
      p_amount: i.amount,
      p_method: i.method,
      p_paid_at: i.paidAt ?? undefined,
      p_external_reference: i.externalReference ?? null,
      p_notes: i.notes ?? null,
      ...common,
    },
    confirm_payment: { p_payment_id: i.paymentId, ...common },
    allocate_payment: {
      p_payment_id: i.paymentId,
      p_charge_id: i.chargeId,
      p_amount: i.amount,
      ...common,
    },
    reverse_payment: {
      p_payment_id: i.paymentId,
      p_reason: i.reason,
      ...common,
    },
    issue_receipt: {
      p_payment_id: i.paymentId,
      p_receipt_number: i.receiptNumber,
      ...common,
    },
    create_assessment: {
      p_course_offering_id: i.courseOfferingId,
      p_assessment_period_id: i.assessmentPeriodId,
      p_type: i.type,
      p_title: i.title,
      p_assessment_date: i.assessmentDate ?? null,
      p_max_score: i.maxScore ?? 20,
      p_weight: i.weight ?? null,
      ...common,
    },
    save_assessment_result: {
      p_assessment_id: i.assessmentId,
      p_student_id: i.studentId,
      p_raw_score: i.rawScore,
      p_status: i.status ?? "ENTERED",
      p_comment: i.comment ?? null,
      ...common,
    },
    publish_assessment: { p_assessment_id: i.assessmentId, ...common },
    correct_published_result: {
      p_assessment_result_id: i.assessmentResultId,
      p_raw_score: i.rawScore,
      p_status: i.status ?? "PUBLISHED",
      p_comment: i.comment ?? null,
      p_reason: i.reason,
      ...common,
    },
    calculate_trimester_result: {
      p_course_offering_id: i.courseOfferingId,
      p_student_id: i.studentId,
      p_assessment_period_id: i.assessmentPeriodId,
      ...common,
    },
    homologate_academic_result: { p_academic_result_id: i.academicResultId, ...common },
    publish_academic_result: { p_academic_result_id: i.academicResultId, ...common },
    calculate_frequency_result: {
      p_course_offering_id: i.courseOfferingId,
      p_student_id: i.studentId,
      p_first_trimester_result_id: i.firstTrimesterResultId,
      p_second_trimester_result_id: i.secondTrimesterResultId,
      p_third_trimester_result_id: i.thirdTrimesterResultId,
      ...common,
    },
    calculate_final_result: {
      p_course_offering_id: i.courseOfferingId,
      p_student_id: i.studentId,
      p_frequency_result_id: i.frequencyResultId,
      p_exam_assessment_result_id: i.examAssessmentResultId,
      ...common,
    },
    open_academic_year: { p_academic_year_id: i.academicYearId, ...common },
    close_academic_year: {
      p_academic_year_id: i.academicYearId,
      p_close_on: i.closeOn ?? undefined,
      p_reason: i.reason ?? null,
      ...common,
    },
    initialize_assessment_periods: {
      p_academic_year_id: i.academicYearId,
      ...common,
    },
    close_assessment_period: {
      p_assessment_period_id: i.assessmentPeriodId,
      p_close_on: i.closeOn ?? undefined,
      p_reason: i.reason ?? null,
      ...common,
    },
    create_class_group: {
      p_academic_year_id: i.academicYearId,
      p_grade_level_id: i.gradeLevelId,
      p_section_code: i.sectionCode,
      p_pathway_id: i.pathwayId ?? null,
      p_shift: i.shift ?? null,
      p_capacity: i.capacity ?? null,
      p_name: i.name ?? null,
      ...common,
    },
    update_class_group: {
      p_class_group_id: i.classGroupId,
      p_section_code: i.sectionCode ?? null,
      p_pathway_id: i.pathwayId ?? null,
      p_shift: i.shift ?? null,
      p_capacity: i.capacity ?? null,
      p_name: i.name ?? null,
      ...common,
    },
    close_class_group: {
      p_class_group_id: i.classGroupId,
      p_closed_on: i.closedOn ?? undefined,
      p_reason: i.reason ?? null,
      ...common,
    },
    generate_class_offerings: { p_class_group_id: i.classGroupId, ...common },
    assign_teacher_to_offering: {
      p_course_offering_id: i.courseOfferingId,
      p_teacher_id: i.teacherId,
      p_starts_on: i.startsOn,
      p_ends_on: i.endsOn ?? null,
      ...common,
    },
    transfer_student_class: {
      p_enrollment_id: i.enrollmentId,
      p_target_class_group_id: i.targetClassGroupId,
      p_transfer_on: i.transferOn,
      p_reason: i.reason,
      ...common,
    },
    create_room: {
      p_school_id: i.schoolId, p_code: i.code, p_name: i.name,
      p_capacity: i.capacity ?? null, ...common,
    },
    create_schedule_period: {
      p_school_id: i.schoolId, p_code: i.code, p_name: i.name,
      p_ordinal: i.ordinal, p_starts_at: i.startsAt, p_ends_at: i.endsAt, ...common,
    },
    upsert_school_calendar_day: {
      p_academic_year_id: i.academicYearId, p_school_date: i.schoolDate,
      p_instructional: i.instructional ?? true, p_label: i.label ?? null, ...common,
    },
    create_schedule_entry: {
      p_academic_year_id: i.academicYearId, p_class_group_id: i.classGroupId,
      p_course_offering_id: i.courseOfferingId, p_teacher_assignment_id: i.teacherAssignmentId,
      p_teacher_id: i.teacherId, p_room_id: i.roomId ?? null, p_period_id: i.periodId,
      p_day_of_week: i.dayOfWeek, p_valid_from: i.validFrom, p_valid_until: i.validUntil ?? null,
      p_notes: i.notes ?? null, ...common,
    },
    set_schedule_entry_status: {
      p_schedule_entry_id: i.scheduleEntryId, p_status: i.status,
      p_reason: i.reason ?? null, ...common,
    },
    configure_curriculum_subject: {
      p_academic_year_id: i.academicYearId,
      p_grade_level_id: i.gradeLevelId,
      p_subject_id: i.subjectId,
      p_pathway_id: i.pathwayId ?? null,
      p_curriculum_area_id: i.curriculumAreaId ?? null,
      p_selection_mode: i.selectionMode ?? "REQUIRED",
      p_choice_group_id: i.choiceGroupId ?? null,
      p_weekly_periods: i.weeklyPeriods ?? null,
      p_ordinal: i.ordinal ?? null,
      ...common,
    },
  };

  return map[name];
}

export async function executeCommand<Name extends CommandName>(
  name: Name,
  input: SigeCommandInputMap[Name],
): Promise<unknown> {
  const { supabase } = await requireAuthenticatedServerClient();

  try {
    const { data, error } = await supabase.rpc(
      RPC_NAMES[name],
      toRpcArgs(name, input),
    );

    if (error) throw error;
    return data;
  } catch (error) {
    throw normalizeSigeError(error);
  }
}
