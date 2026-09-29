export type UUID = string;
export type ISODate = string;
export type ISODateTime = string;

export type IdempotentCommand = {
  idempotencyKey: string;
  requestHash?: string;
};

export type CommandInput<T extends object = Record<string, never>> =
  T & IdempotentCommand;

export type EnrollmentEntryType = "INITIAL" | "TRANSFER_IN" | "REENTRY" | "RENEWAL";
export type PaymentMethod = "CASH" | "BANK_TRANSFER" | "MOBILE_MONEY" | "CARD" | "OTHER";
export type AssessmentType = "ACS" | "AT" | "EXAM" | "OTHER";
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
export interface ConfigureCurriculumSubjectInput extends IdempotentCommand {
  academicYearId: UUID; gradeLevelId: UUID; subjectId: UUID; pathwayId?: UUID;
  curriculumAreaId?: UUID; selectionMode?: CurriculumSelectionMode;
  choiceGroupId?: UUID; weeklyPeriods?: number; ordinal?: number;
}

export type SigeCommandInputMap = {
  register_student: RegisterStudentInput;
  create_guardian: CreateGuardianInput;
  enroll_student: EnrollStudentInput;
  place_student_in_class: PlaceStudentInClassInput;
  record_payment: RecordPaymentInput;
  confirm_payment: ConfirmPaymentInput;
  allocate_payment: AllocatePaymentInput;
  reverse_payment: ReversePaymentInput;
  issue_receipt: IssueReceiptInput;
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
};

export type CommandName = keyof SigeCommandInputMap;
