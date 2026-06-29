# Team Context — Royal HRMS

---

## 2026-06-29 — G. Durga Prasad

### Summary
Full-day backend session covering employee document storage, onboarding pipeline production gaps, employee/candidate module separation, approval form data persistence, and email delivery investigation.

---

### 1. Employee Document Storage Path Fix

**Problem:** 4 documents were storing to different URLs — 3 went to a date-based path, the 4th to a separate URL.

**Fix:** Changed `EmployeeDocument.file` from a static `upload_to='employee_documents/%Y/%m/'` to a callable `_employee_doc_path` that builds a per-employee-ID folder:

```python
def _employee_doc_path(instance, filename):
    uid = getattr(instance.user, 'employee_id', None) or str(instance.user_id)
    return os.path.join('employee_documents', str(uid), os.path.basename(filename))
```

Migration: `accounts/migrations/0024_employee_doc_upload_path.py`

---

### 2. Onboarding Flow — Production Gaps Filled

**Problem:** After sending portal login to a candidate, multiple gaps existed in the onboarding flow.

**Fixes applied:**

- **Approval/Rejection emails:** Added `onboarding_approved` and `onboarding_rejected` email templates (seeded via migration `0025`). `OnboardingApproveView` now sends the appropriate email on every HR decision.
- **Hardcoded portal URL removed:** `SendPortalLoginView` previously hardcoded `'https://royalhrms.com/login'`. Replaced with `Company.portal_url` (new field on the Company model, admin-configurable).
- **Pipeline endpoint added:** `GET /api/onboarding/pipeline/` — returns all candidates currently in `pending` or `submitted` onboarding state, with recruitment linkage (`candidate_id`, `position_applied`, `candidate_status`) and summary stats `{pending: N, submitted: N}`.
- **Resend credentials endpoint added:** `POST /api/recruitment/candidates/<pk>/resend-portal-login/` — generates a new temp password, re-sends the `portal_invite` email, and creates `CandidateEmail` + `CandidateLog` + `AuditLog` records.
- **N+1 query fixed:** Approvals list now uses `select_related('role', 'profile')` + `prefetch_related('employee_documents')` and batch-fetches `Candidate` records per page.

---

### 3. Seeded Users Polluting the Pipeline

**Problem:** The pipeline was showing seeded accounts (`hradmin`, `employee`, `manager`) because they have `onboarding_status='pending'` by default.

**Fix:** Added `candidate_portal__isnull=False` filter to `OnboardingPipelineView` — only users linked to a `Candidate` record via the `portal_user` FK are shown.

---

### 4. Onboarding Candidates Appearing in Employees Module

**Problem:** Candidates who had received portal credentials (and were still in onboarding) were appearing in the employees list.

**Fix:** Added `.exclude(employee_id='')` to `EmployeeListCreateView.get()`.  
Also: directly-added employees now get `onboarding_status=ONBOARDING_COMPLETE` on creation so they never appear in the pipeline.

---

### 5. `position_applied` → `designation` and `branch` Not Copying on Approval

**Problem:** After an onboarding candidate was approved and converted to an employee, their `designation` and `branch` fields were empty — the recruitment data was not being carried over.

**Fix:** `OnboardingApproveView` now fetches the linked `Candidate` record before saving and copies:
- `candidate.position_applied` → `target.designation`
- `candidate.branch.branch_name` → `target.branch`

Retroactive script run — fixed 1 already-converted employee (`shivasurya821@gmail.com`). Safura (`RSS00015`) was verified in DB and already had correct values.

---

### 6. Approval Form Payload (`designation`, `department`) Not Being Saved

**Problem:** The frontend sends `designation` and `department` in the approval payload, but the backend was ignoring them — only falling back to the candidate's recruitment record.

**Fix:** `OnboardingApproveView` now reads `designation` and `department` from `request.data` and applies them with priority:

- HR-provided `designation` wins; candidate `position_applied` is used only as fallback.
- HR-provided `department` is always saved (no candidate-record fallback for department).
- `department` added to `update_fields` so it persists.

---

### 7. Selection Email Investigation

**Problem reported:** Selection email not arriving at recipient's inbox.

**Investigation result:** Backend is working correctly.
- All `CandidateEmail` records show `status: 'sent'` — no failures on record.
- Live test confirmed SMTP sends without error.
- `send_template_email` uses an explicit `smtp.EmailBackend` connection (bypasses `EMAIL_BACKEND = console.EmailBackend` in dev settings).

**Root cause:** Gmail's spam/promotions filter. The SMTP sender is `demohrms6@gmail.com` (a plain Gmail account with no domain authentication). Gmail routes these emails to the **Promotions** or **Spam** tab for recipient Gmail accounts.

**Recommendation:** Switch to a transactional email service (SendGrid, Mailgun, AWS SES) with a verified company domain for reliable deliverability in production.

---

### Files Changed Today

| File | Change |
|------|--------|
| `backend/apps/accounts/models.py` | `_employee_doc_path` callable; `Company.portal_url` field |
| `backend/apps/accounts/migrations/0024_*` | `AlterField` for `EmployeeDocument.file` |
| `backend/apps/accounts/migrations/0025_*` | `Company.portal_url`; seeds `onboarding_approved` + `onboarding_rejected` templates |
| `backend/apps/accounts/serializers.py` | `OnboardingPipelineSerializer`; `candidate_id` + `position_applied` on `OnboardingApprovalSerializer`; `portal_url` on `CompanySerializer` |
| `backend/apps/accounts/views.py` | `EmployeeListCreateView` exclude filter; `OnboardingPipelineView` (new); `OnboardingApprovalsListView` N+1 fix; `OnboardingApproveView` — designation/branch copy, approval/rejection emails, HR payload fields saved |
| `backend/apps/accounts/urls.py` | `onboarding/pipeline/` route added |
| `backend/apps/recruitment/views.py` | `SendPortalLoginView` portal_url fix; `ResendPortalLoginView` (new) |
| `backend/apps/recruitment/urls.py` | `candidates/<pk>/resend-portal-login/` route added |
