export const API = {
  auth: {
    login:          "/login/",
    logout:         "/logout/",
    forgotPassword: "/forgot-password/",
    verifyOtp:      "/verify-otp/",
    resetPassword:  "/reset-password/",
    changePassword: "/change-password/",
  },

  announcements: {
    list:   "/announcements/",
    detail: (id: string | number) => `/announcements/${id}/`,
    view:   (id: string | number) => `/announcements/${id}/view/`,
    react:  (id: string | number) => `/announcements/${id}/react/`,
  },

  branches: {
    list:         "/branch/branches/",
    stats:        "/branch/branches/stats/",
    distribution: "/branch/branches/distribution/",
    previewCode:  "/branch/branches/preview-code/",
    detail:       (id: string | number) => `/branch/branches/${id}/`,
    states:       "/branch/states/",
    cities:       (stateId: string | number) => `/branch/states/${stateId}/cities/`,
  },

  departments: {
    list:   "/departments/",
    detail: (id: string | number) => `/departments/${id}/`,
  },

  designations: {
    list:   "/designations/",
    detail: (id: string | number) => `/designations/${id}/`,
  },

  employees: {
    list:     "/employees/",
    detail:   (id: string) => `/employees/${id}/`,
    profile:  (id: string) => `/employees/${id}/profile/`,
    branches: "/branch/branches/",
  },

  roles: {
    list:   "/roles/",
    detail: (id: string | number) => `/roles/${id}/`,
  },

  permissions: {
    list: "/permissions/",
  },

  settings: {
    audit:          "/settings/audit/",
    company:        "/settings/company/",
    employeeCode:   "/settings/employee-code/",
    emailTemplates: "/settings/email-templates/",
  },

  recruitment: {
    candidates:      "/recruitment/candidates/",
    stats:           "/recruitment/candidates/stats/",
    review:          "/recruitment/candidates/review/",
    detail:          (id: number) => `/recruitment/candidates/${id}/`,
    status:          (id: number) => `/recruitment/candidates/${id}/status/`,
    hrDecision:      (id: number) => `/recruitment/candidates/${id}/hr-decision/`,
    sendPortalLogin: (id: number) => `/recruitment/candidates/${id}/send-portal-login/`,
    emailLogs:       "/recruitment/emails/",
  },

  onboarding: {
    profile:     "/onboarding/profile/",
    profileStep: (step: number) => `/onboarding/profile/step/${step}/`,
    documents:   "/onboarding/documents/",
    submit:      "/onboarding/submit/",
    approvals:   "/onboarding/approvals/",
    approve:     (userId: string) => `/onboarding/approvals/${userId}/approve/`,
  },
} as const;
