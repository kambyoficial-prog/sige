export interface AccessRole {
  code: string;
  name: string;
}

export interface AccessMembership {
  school_id: string;
  school_code: string;
  school_name: string;
  roles: AccessRole[];
  permissions: string[];
}

export interface CurrentAccessContext {
  auth_user_id: string;
  app_account_id: string;
  person_id: string;
  person: {
    id: string;
    full_name: string;
    first_name: string | null;
    last_name: string | null;
    email: string | null;
    phone: string | null;
  } | null;
  memberships: AccessMembership[];
}
