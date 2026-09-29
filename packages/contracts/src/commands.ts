export type UUID = string;
export type ISODate = string;
export type ISODateTime = string;

export type IdempotentCommand = {
  idempotencyKey: string;
  requestHash?: string;
};

export type CommandInput<T extends object = Record<string, never>> =
  T & IdempotentCommand;

export type EnrollmentEntryType = "INITIAL" | "TRANSFER_IN" | "REENTRY";
export type PaymentMethod = "CASH" | "BANK_TRANSFER" | "MOBILE_MONEY" | "CARD" | "OTHER";
export type AssessmentType = "ACS" | "ACP" | "AT" | "EXAM" | "RECOVERY" | "OTHER";
export type AssessmentResultStatus =
  | "MISSING"
  | "ENTERED"
  | "ABSENT"
  | "EXCUSED"
  | "INVALIDATED"
  | "PUBLISHED";
export type CurriculumSelectionMode = "REQUIRED" | "OPTIONAL" | "CHOICE";

export interface RegisterStudentInput extends IdempotentCommand {
  schoolId: UUID;
  schoolNumber: string;
  fullName: string;
  firstName?: string;
  lastName?: string;
  gender?: string;
  birthDate?: ISODate;
  nationalId?: string;
  phone?: string;
  email?: string;
  address?: string;
  admissionDate?: ISODate;
}

export interface CreateGuardianInput extends IdempotentCommand {
  schoolId: UUID;
  studentId: UUID;
  fullName: string;
  relationship?: string;
  occupation?: string;
  identityNumber?: string;
  address?: string;
  phone?: string;
  gender?: string;
  birthDate?: ISODate;
  nationalId?: string;
  isPrimary?: boolean;
  livesWithStudent?: boolean;
}

export interface AssignClassGroupDirectorInput extends IdempotentCommand {
  classGroupId: UUID;
  teacherId: UUID;
  startsOn: ISODate;
  endsOn?: ISODate;
  reason?: string;
}

export interface EnrollStudentInput extends IdempotentCommand {
  studentId: UUID;
  academicYearId: UUID;
  gradeLevelId: UUID;
  entryType?: EnrollmentEntryType;
  enrolledOn?: ISODate;
}

export interface PlaceStudentInClassInput extends IdempotentCommand {
  enrollmentId: UUID;
  classGroupId: UUID;
  startsOn?: ISODate;
  endsOn?: ISODate;
  reason?: string;
}


export interface CreateFeeTypeInput extends IdempotentCommand { schoolId: UUID; code: string; name: string; }
export interface CreateFeePlanInput extends IdempotentCommand { schoolId: UUID; academicYearId: UUID; code: string; name: string; }
export interface AddFeePlanItemInput extends IdempotentCommand { feePlanId: UUID; feeTypeId: UUID; amount: number; dueDay?: number; sequenceNo?: number; }
export interface CreateTransportServiceInput extends IdempotentCommand { schoolId: UUID; code: string; name: string; route?: string; stop?: string; amount?: number; }
export interface AssignStudentTransportInput extends IdempotentCommand { studentId: UUID; academicYearId: UUID; transportServiceId: UUID; startsOn?: ISODate; endsOn?: ISODate; }
export interface CreateChargeInput extends IdempotentCommand { studentId: UUID; academicYearId: UUID; amount: number; dueOn: ISODate; feeTypeId?: UUID; description?: string; }
export type ChargeAdjustmentType = "DISCOUNT" | "WAIVER" | "REVERSAL" | "SURCHARGE" | "CORRECTION";
export interface AdjustChargeInput extends IdempotentCommand { chargeId: UUID; type: ChargeAdjustmentType; amount: number; reason: string; }

export interface RecordPaymentInput extends IdempotentCommand {
  studentId: UUID;
  amount: number;
  method: PaymentMethod;
  paidAt?: ISODateTime;
  externalReference?: string;
  notes?: string;
}

export interface ConfirmPaymentInput extends IdempotentCommand { paymentId: UUID; }
export interface AllocatePaymentInput extends IdempotentCommand { paymentId: UUID; chargeId: UUID; amount: number; }
export interface ReversePaymentInput extends IdempotentCommand { paymentId: UUID; reason: string; }
export interface IssueReceiptInput extends IdempotentCommand { paymentId: UUID; receiptNumber: string; }

export interface CreateAssessmentDefinitionInput extends IdempotentCommand {
  courseOfferingId: UUID;
  assessmentPeriodId: UUID;
  code: string;
  name: string;
  type: AssessmentType;
  ordinal: number;
  required?: boolean;
  countsInMacs?: boolean;
  maxScore?: number;
  weight?: number;
}

export interface CreateAssessmentInput extends IdempotentCommand {
  courseOfferingId: UUID;
  assessmentPeriodId: UUID;
  type: AssessmentType;
  title: string;
  assessmentDate?: ISODate;
  maxScore?: number;
  weight?: number;
}

export interface SaveAssessmentResultInput extends IdempotentCommand {
  assessmentId: UUID;
  studentId: UUID;
  rawScore: number | null;
  status?: AssessmentResultStatus;
  comment?: string;
}

export interface PublishAssessmentInput extends IdempotentCommand { assessmentId: UUID; }
export interface CorrectPublishedResultInput extends IdempotentCommand {
  assessmentResultId: UUID;
  rawScore: number;
  status?: "PUBLISHED";
  comment?: string;
  reason: string;
}
export interface CalculateTrimesterResultInput extends IdempotentCommand {
  courseOfferingId: UUID; studentId: UUID; assessmentPeriodId: UUID;
}
export interface HomologateAcademicResultInput extends IdempotentCommand { academicResultId: UUID; }
export interface PublishAcademicResultInput extends IdempotentCommand { academicResultId: UUID; }
export interface CalculateFrequencyResultInput extends IdempotentCommand {
  courseOfferingId: UUID; studentId: UUID;
  firstTrimesterResultId: UUID; secondTrimesterResultId: UUID; thirdTrimesterResultId: UUID;
}
export interface CalculateFinalResultInput extends IdempotentCommand {
  courseOfferingId: UUID; studentId: UUID;
  frequencyResultId: UUID; examAssessmentResultId: UUID;
}
export interface OpenAcademicYearInput extends IdempotentCommand { academicYearId: UUID; }
export interface CloseAcademicYearInput extends IdempotentCommand {
  academicYearId: UUID; closeOn?: ISODate; reason?: string;
}
export interface InitializeAssessmentPeriodsInput extends IdempotentCommand { academicYearId: UUID; }
export interface CloseAssessmentPeriodInput extends IdempotentCommand {
  assessmentPeriodId: UUID; closeOn?: ISODate; reason?: string;
}
export interface CreateClassGroupInput extends IdempotentCommand {
  academicYearId: UUID; gradeLevelId: UUID; sectionCode: string;
  pathwayId?: UUID; shift?: string; capacity?: number; name?: string;
}
export interface UpdateClassGroupInput extends IdempotentCommand {
  classGroupId: UUID; sectionCode?: string; pathwayId?: UUID;
  shift?: string; capacity?: number; name?: string;
}
export interface CloseClassGroupInput extends IdempotentCommand {
  classGroupId: UUID; closedOn?: ISODate; reason?: string;
}
export interface GenerateClassOfferingsInput extends IdempotentCommand { classGroupId: UUID; }
export interface AssignTeacherToOfferingInput extends IdempotentCommand {
  courseOfferingId: UUID; teacherId: UUID; startsOn: ISODate; endsOn?: ISODate;
}
export interface TransferStudentClassInput extends IdempotentCommand {
  enrollmentId: UUID; targetClassGroupId: UUID; transferOn: ISODate; reason: string;
}
export type ScheduleEntryStatus = "DRAFT" | "ACTIVE" | "ENDED" | "CANCELLED";

export interface CreateRoomInput extends IdempotentCommand {
  schoolId: UUID; code: string; name: string; capacity?: number;
}
export interface CreateSchedulePeriodInput extends IdempotentCommand {
  schoolId: UUID; code: string; name: string; ordinal: number; startsAt: string; endsAt: string;
}
export interface UpsertSchoolCalendarDayInput extends IdempotentCommand {
  academicYearId: UUID; schoolDate: ISODate; instructional?: boolean; label?: string;
}
export interface CreateScheduleEntryInput extends IdempotentCommand {
  academicYearId: UUID; classGroupId: UUID; courseOfferingId: UUID;
  teacherAssignmentId: UUID; teacherId: UUID; roomId?: UUID; periodId: UUID;
  dayOfWeek: number; validFrom: ISODate; validUntil?: ISODate; notes?: string;
}
export interface SetScheduleEntryStatusInput extends IdempotentCommand {
  scheduleEntryId: UUID; status: ScheduleEntryStatus; reason?: string;
}
export type AttendanceStatus = "PRESENT" | "ABSENT" | "EXCUSED" | "LATE";
export interface OpenClassSessionInput extends IdempotentCommand {
  scheduleEntryId: UUID; sessionDate: ISODate; topic?: string; notes?: string;
}
export interface CloseClassSessionInput extends IdempotentCommand {
  classSessionId: UUID; reason?: string;
}
export interface RecordSessionAttendanceInput extends IdempotentCommand {
  classSessionId: UUID; studentId: UUID; status: AttendanceStatus;
  minutesLate?: number; reason?: string;
}

export interface ConfigureCurriculumSubjectInput extends IdempotentCommand {
  academicYearId: UUID; gradeLevelId: UUID; subjectId: UUID; pathwayId?: UUID;
  curriculumAreaId?: UUID; selectionMode?: CurriculumSelectionMode;
  choiceGroupId?: UUID; weeklyPeriods?: number; ordinal?: number;
}


export type CreateExamSessionInput = {
  academicYearId: string; gradeLevelId: string; epoch: 1 | 2; startsOn: string; endsOn: string;
  idempotencyKey: string; requestHash?: string | null;
};
export type SetExamSessionStatusInput = {
  examSessionId: string; status: "OPEN" | "CLOSED" | "CANCELLED"; idempotencyKey: string; requestHash?: string | null;
};
export type RegisterExamCandidateInput = {
  examSessionId: string; studentId: string; courseOfferingId: string;
  eligibilityStatus: "PENDING" | "ELIGIBLE" | "INELIGIBLE" | "AUTHORIZED_ABSENCE" | "FRAUD_BLOCKED";
  reason?: string | null; idempotencyKey: string; requestHash?: string | null;
};

export type SigeCommandInputMap = {
  create_exam_session: CreateExamSessionInput;
  set_exam_session_status: SetExamSessionStatusInput;
  register_exam_candidate: RegisterExamCandidateInput;
  register_student: RegisterStudentInput;
  create_guardian: CreateGuardianInput;
  assign_class_group_director: AssignClassGroupDirectorInput;
  enroll_student: EnrollStudentInput;
  place_student_in_class: PlaceStudentInClassInput;
  create_fee_type: CreateFeeTypeInput;
  create_fee_plan: CreateFeePlanInput;
  add_fee_plan_item: AddFeePlanItemInput;
  create_transport_service: CreateTransportServiceInput;
  assign_student_transport: AssignStudentTransportInput;
  create_charge: CreateChargeInput;
  adjust_charge: AdjustChargeInput;
  record_payment: RecordPaymentInput;
  confirm_payment: ConfirmPaymentInput;
  allocate_payment: AllocatePaymentInput;
  reverse_payment: ReversePaymentInput;
  issue_receipt: IssueReceiptInput;
  create_assessment_definition: CreateAssessmentDefinitionInput;
  create_assessment: CreateAssessmentInput;
  save_assessment_result: SaveAssessmentResultInput;
  publish_assessment: PublishAssessmentInput;
  correct_published_result: CorrectPublishedResultInput;
  calculate_trimester_result: CalculateTrimesterResultInput;
  homologate_academic_result: HomologateAcademicResultInput;
  publish_academic_result: PublishAcademicResultInput;
  calculate_frequency_result: CalculateFrequencyResultInput;
  calculate_final_result: CalculateFinalResultInput;
  open_academic_year: OpenAcademicYearInput;
  close_academic_year: CloseAcademicYearInput;
  initialize_assessment_periods: InitializeAssessmentPeriodsInput;
  close_assessment_period: CloseAssessmentPeriodInput;
  create_class_group: CreateClassGroupInput;
  update_class_group: UpdateClassGroupInput;
  close_class_group: CloseClassGroupInput;
  generate_class_offerings: GenerateClassOfferingsInput;
  assign_teacher_to_offering: AssignTeacherToOfferingInput;
  transfer_student_class: TransferStudentClassInput;
  configure_curriculum_subject: ConfigureCurriculumSubjectInput;
  create_room: CreateRoomInput;
  create_schedule_period: CreateSchedulePeriodInput;
  upsert_school_calendar_day: UpsertSchoolCalendarDayInput;
  create_schedule_entry: CreateScheduleEntryInput;
  set_schedule_entry_status: SetScheduleEntryStatusInput;
  open_class_session: OpenClassSessionInput;
  close_class_session: CloseClassSessionInput;
  record_session_attendance: RecordSessionAttendanceInput;
};

export type CommandName = keyof SigeCommandInputMap;
