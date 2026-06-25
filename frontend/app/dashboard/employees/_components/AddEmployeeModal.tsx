"use client";

import { useState, type ReactNode } from "react";
import {
  DEPARTMENT_OPTIONS,
  type Employee,
  type Gender,
  type EmployeeStatus,
} from "../_data";

/* ─────────────────────────────────────────────────────────────
   Shared style constants
───────────────────────────────────────────────────────────── */
const INPUT =
  "w-full px-3.5 py-2.5 rounded-lg border text-[13px] bg-white text-[var(--on-bg)] " +
  "placeholder:text-[#a5b0c2] focus:outline-none focus:ring-2 " +
  "focus:ring-[rgba(30,78,140,0.12)] transition-colors";
const B_OK  = "border-[var(--outline-v)] focus:border-[var(--primary)]";
const B_ERR = "border-[var(--error)]     focus:border-[var(--error)]";
const LABEL = "block text-[12.5px] font-semibold text-[var(--on-bg)] mb-1.5";
const SEL_STYLE = {
  backgroundImage:
    "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' " +
    "viewBox='0 0 24 24' fill='none' stroke='%234f5d75' stroke-width='2.2' stroke-linecap='round' " +
    "stroke-linejoin='round'><polyline points='6 9 12 15 18 9'/></svg>\")",
  backgroundRepeat:   "no-repeat" as const,
  backgroundPosition: "right 10px center" as const,
  backgroundSize:     "15px" as const,
};

/* ─────────────────────────────────────────────────────────────
   Option lists
───────────────────────────────────────────────────────────── */
const SHIFTS        = ["General (9-6)", "Morning (6-2)", "Evening (2-10)", "Night (10-6)"];
const WORK_TYPES    = ["Office", "WFH", "Hybrid"];
const ENTRY_SOURCES = ["Biometric", "Mobile App", "Web Portal", "Manual"];
const WEEKLY_DAYS   = ["5 Days (Mon–Fri)", "5.5 Days", "6 Days (Mon–Sat)"];
const EMP_TYPES     = ["Permanent", "Contract", "Intern", "Probation"];
const CATEGORIES    = ["General", "OBC", "SC", "ST", "EWS"];
const GENDERS       = ["male", "female", "transgender"] as const;
const MARITAL       = ["Single", "Married", "Divorced", "Widowed"];

/* ─────────────────────────────────────────────────────────────
   Form state
───────────────────────────────────────────────────────────── */
interface FormState {
  /* Personal */
  firstName:      string;
  lastName:       string;
  email:          string;
  phone:          string;
  gender:         string;
  maritalStatus:  string;
  /* Employment */
  department:     string;
  designation:    string;
  employeeType:   string;
  employeeCategory: string;
  reportingManager: string;
  dateOfJoining:  string;
  /* Schedule */
  shift:          string;
  workType:       string;
  weeklyDays:     string;
  workEntrySource: string;
  /* Compensation */
  monthlySalary:  string;
}

const EMPTY: FormState = {
  firstName: "", lastName: "", email: "", phone: "",
  gender: "male", maritalStatus: "Single",
  department: "Engineering", designation: "",
  employeeType: "Permanent", employeeCategory: "General",
  reportingManager: "",
  dateOfJoining: "",
  shift: "General (9-6)", workType: "Office",
  weeklyDays: "5 Days (Mon–Fri)", workEntrySource: "Biometric",
  monthlySalary: "",
};

type F = keyof FormState;
type Errors = Partial<Record<
  "firstName" | "lastName" | "email" | "designation" |
  "dateOfJoining" | "monthlySalary" | "duplicate",
  string
>>;

/* ─────────────────────────────────────────────────────────────
   Component
───────────────────────────────────────────────────────────── */
export default function AddEmployeeModal({
  onClose,
  onCreate,
  existingCount,
  existingEmployees,
}: {
  onClose:           () => void;
  onCreate:          (e: Employee) => void;
  existingCount:     number;
  existingEmployees: Employee[];
}) {
  const [form,   setForm]   = useState<FormState>(EMPTY);
  const [errors, setErrors] = useState<Errors>({});
  const [saving, setSaving] = useState(false);

  const set = (k: F, v: string) => {
    setForm(f => ({ ...f, [k]: v }));
    if (k in errors) setErrors(e => ({ ...e, [k]: undefined, duplicate: undefined }));
  };

  /* ── validation ─────────────────────────────────────────── */
  function validate(): boolean {
    const e: Errors = {};

    if (!form.firstName.trim())     e.firstName     = "First name is required";
    if (!form.lastName.trim())      e.lastName      = "Last name is required";
    if (!form.designation.trim())   e.designation   = "Designation is required";
    if (!form.dateOfJoining)        e.dateOfJoining = "Date of joining is required";

    if (!form.email.trim())         e.email = "Email is required";
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email))
                                    e.email = "Enter a valid email";

    if (!form.monthlySalary.trim()) e.monthlySalary = "Monthly salary is required";
    else if (isNaN(Number(form.monthlySalary)) || Number(form.monthlySalary) <= 0)
                                    e.monthlySalary = "Enter a valid amount";

    /* duplicate — email */
    if (!e.email && form.email.trim()) {
      const dup = existingEmployees.find(
        emp => emp.email.toLowerCase() === form.email.trim().toLowerCase(),
      );
      if (dup) e.email = `Already registered to ${dup.firstName} ${dup.lastName}`;
    }

    /* duplicate — full name */
    if (!e.firstName && !e.lastName && form.firstName.trim() && form.lastName.trim()) {
      const dup = existingEmployees.find(
        emp =>
          emp.firstName.toLowerCase() === form.firstName.trim().toLowerCase() &&
          emp.lastName.toLowerCase()  === form.lastName.trim().toLowerCase(),
      );
      if (dup)
        e.duplicate = `"${dup.firstName} ${dup.lastName}" already exists (${dup.code}). Verify before adding.`;
    }

    setErrors(e);
    return Object.keys(e).length === 0;
  }

  /* ── submit ─────────────────────────────────────────────── */
  function submit() {
    if (!validate()) return;
    setSaving(true);
    const code = `RSS${String(existingCount + 1).padStart(5, "0")}D`;
    const created: Employee = {
      id: code, code,
      firstName:     form.firstName.trim(),
      middleName:    "",
      lastName:      form.lastName.trim(),
      email:         form.email.trim(),
      phone:         form.phone.trim(),
      department:    form.department,
      designation:   form.designation.trim(),
      dateOfJoining: form.dateOfJoining,
      dateOfBirth:   "",
      location:      "",
      gender:        form.gender as Gender,
      status:        "onboarding" as EmployeeStatus,
      details: {
        code,
        firstName:        form.firstName.trim(),
        lastName:         form.lastName.trim(),
        gender:           form.gender,
        maritalStatus:    form.maritalStatus,
        dateOfJoining:    form.dateOfJoining,
        department:       form.department,
        designation:      form.designation.trim(),
        employmentType:   form.employeeType,
        category:         form.employeeCategory,
        reportingTo:      form.reportingManager,
        shift:            form.shift,
        workType:         form.workType,
        weeklyDays:       form.weeklyDays,
        workEntrySource:  form.workEntrySource,
        confirmationStatus: "On Probation",
        esiLocation:      "Corporate",
        metroTds:         "Metro",
        esiDispensary:    "N/A",
        nationality:      "Indian",
        loginEmail:       form.email.trim(),
        personalEmail:    form.email.trim(),
        mobileNumber:     form.phone.trim(),
        ssRole:           "Employee",
        portalAccess:     "enabled",
        monthlySalary:    form.monthlySalary.trim(),
      },
      tables: {},
    };
    onCreate(created);
    setSaving(false);
  }

  /* manager options from existing employees */
  const managerOptions = existingEmployees.map(
    e => `${e.firstName} ${e.lastName}`,
  );

  return (
    <div
      className="fixed inset-0 z-[300] flex items-center justify-center p-4"
      style={{ background: "rgba(10,20,40,0.5)", backdropFilter: "blur(6px)" }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full flex flex-col"
        style={{ maxWidth: 660, maxHeight: "92vh" }}
      >
        {/* ── Header ──────────────────────────────────────── */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--outline-v)] flex-shrink-0">
          <div className="flex items-center gap-2.5">
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ background: "rgba(30,78,140,0.10)" }}
            >
              <i className="ti ti-user-plus text-[16px]" style={{ color: "var(--primary)" }} />
            </div>
            <h2 className="text-[16px] font-bold text-[var(--on-bg)]">Add New Employee</h2>
          </div>
          <button
            onClick={onClose}
            suppressHydrationWarning
            className="w-8 h-8 flex items-center justify-center rounded-lg text-[var(--on-variant)] hover:bg-[var(--bg-low)] transition-colors"
          >
            <i className="ti ti-x text-[18px]" />
          </button>
        </div>

        {/* ── Body ────────────────────────────────────────── */}
        <div className="px-6 py-5 space-y-5 overflow-y-auto flex-1">

          {/* ╔═ SECTION 1 — Personal Information ══════════╗ */}
          <Section title="Personal Information" icon="ti-user" />

          <div className="grid grid-cols-2 gap-4">
            <Field label="First Name" required error={errors.firstName}>
              <input value={form.firstName} onChange={e => set("firstName", e.target.value)}
                placeholder="e.g. Anjali" suppressHydrationWarning
                className={`${INPUT} ${errors.firstName ? B_ERR : B_OK}`} />
            </Field>
            <Field label="Last Name" required error={errors.lastName}>
              <input value={form.lastName} onChange={e => set("lastName", e.target.value)}
                placeholder="e.g. Sharma" suppressHydrationWarning
                className={`${INPUT} ${errors.lastName ? B_ERR : B_OK}`} />
            </Field>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Email" required error={errors.email}>
              <input type="email" value={form.email} onChange={e => set("email", e.target.value)}
                placeholder="anjali@royal.com" suppressHydrationWarning
                className={`${INPUT} ${errors.email ? B_ERR : B_OK}`} />
            </Field>
            <Field label="Phone">
              <input type="tel" value={form.phone} onChange={e => set("phone", e.target.value)}
                placeholder="+91 98765 43210" suppressHydrationWarning
                className={`${INPUT} ${B_OK}`} />
            </Field>
          </div>

          <div className="grid grid-cols-2 gap-4">
            {/* Gender — radio */}
            <Field label="Gender">
              <div className="flex items-center gap-5 h-[42px]">
                {GENDERS.map(g => (
                  <label key={g} className="flex items-center gap-1.5 cursor-pointer text-[13px] capitalize select-none"
                    style={{ color: "var(--on-bg)" }}>
                    <input type="radio" name="add-gender" checked={form.gender === g}
                      onChange={() => set("gender", g)} suppressHydrationWarning
                      className="w-4 h-4 cursor-pointer" style={{ accentColor: "var(--primary)" }} />
                    {g}
                  </label>
                ))}
              </div>
            </Field>
            <Field label="Marital Status">
              <Sel value={form.maritalStatus} onChange={v => set("maritalStatus", v)}>
                {MARITAL.map(m => <option key={m} value={m}>{m}</option>)}
              </Sel>
            </Field>
          </div>

          {/* ╔═ SECTION 2 — Employment Details ════════════╗ */}
          <Section title="Employment Details" icon="ti-id" />

          <div className="grid grid-cols-2 gap-4">
            <Field label="Department" required>
              <Sel value={form.department} onChange={v => set("department", v)}>
                {DEPARTMENT_OPTIONS.map(d => <option key={d} value={d}>{d}</option>)}
              </Sel>
            </Field>
            <Field label="Designation" required error={errors.designation}>
              <input value={form.designation} onChange={e => set("designation", e.target.value)}
                placeholder="e.g. Software Engineer" suppressHydrationWarning
                className={`${INPUT} ${errors.designation ? B_ERR : B_OK}`} />
            </Field>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Employee Type">
              <Sel value={form.employeeType} onChange={v => set("employeeType", v)}>
                {EMP_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
              </Sel>
            </Field>
            <Field label="Employee Category">
              <Sel value={form.employeeCategory} onChange={v => set("employeeCategory", v)}>
                {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
              </Sel>
            </Field>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Reporting Manager">
              <Sel value={form.reportingManager} onChange={v => set("reportingManager", v)}>
                <option value="">— Select Manager —</option>
                {managerOptions.map(m => <option key={m} value={m}>{m}</option>)}
              </Sel>
            </Field>
            <Field label="Date of Joining" required error={errors.dateOfJoining}>
              <input type="date" value={form.dateOfJoining}
                onChange={e => set("dateOfJoining", e.target.value)} suppressHydrationWarning
                className={`${INPUT} ${errors.dateOfJoining ? B_ERR : B_OK}`} />
            </Field>
          </div>

          {/* ╔═ SECTION 3 — Work Schedule ══════════════════╗ */}
          <Section title="Work Schedule" icon="ti-clock" />

          <div className="grid grid-cols-2 gap-4">
            <Field label="Shift">
              <Sel value={form.shift} onChange={v => set("shift", v)}>
                {SHIFTS.map(s => <option key={s} value={s}>{s}</option>)}
              </Sel>
            </Field>
            <Field label="Work Type">
              <Sel value={form.workType} onChange={v => set("workType", v)}>
                {WORK_TYPES.map(w => <option key={w} value={w}>{w}</option>)}
              </Sel>
            </Field>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Weekly Working Days">
              <Sel value={form.weeklyDays} onChange={v => set("weeklyDays", v)}>
                {WEEKLY_DAYS.map(d => <option key={d} value={d}>{d}</option>)}
              </Sel>
            </Field>
            <Field label="Work Entry Source">
              <Sel value={form.workEntrySource} onChange={v => set("workEntrySource", v)}>
                {ENTRY_SOURCES.map(s => <option key={s} value={s}>{s}</option>)}
              </Sel>
            </Field>
          </div>

          {/* ╔═ SECTION 4 — Compensation ═══════════════════╗ */}
          <Section title="Compensation" icon="ti-currency-rupee" />

          <Field label="Monthly Salary (₹)" required error={errors.monthlySalary}>
            <input type="number" value={form.monthlySalary} min={0}
              onChange={e => set("monthlySalary", e.target.value)}
              placeholder="e.g. 55000" suppressHydrationWarning
              className={`${INPUT} ${errors.monthlySalary ? B_ERR : B_OK}`} />
          </Field>

          {/* Duplicate name warning */}
          {errors.duplicate && (
            <div className="flex items-start gap-2.5 px-4 py-3 rounded-lg"
              style={{ background: "rgba(192,57,43,0.07)", border: "1px solid rgba(192,57,43,0.25)" }}>
              <i className="ti ti-alert-triangle text-[15px] mt-0.5 flex-shrink-0" style={{ color: "var(--error)" }} />
              <p className="text-[13px] font-medium" style={{ color: "var(--error)" }}>{errors.duplicate}</p>
            </div>
          )}

          {/* Info banner */}
          <div className="flex items-start gap-2.5 px-4 py-3 rounded-lg"
            style={{ background: "rgba(30,78,140,0.06)", border: "1px solid rgba(30,78,140,0.15)" }}>
            <i className="ti ti-info-circle text-[15px] mt-0.5 flex-shrink-0" style={{ color: "var(--primary)" }} />
            <p className="text-[13px]" style={{ color: "var(--primary)" }}>
              Once added, a welcome email will be sent and the employee will receive login credentials.
            </p>
          </div>
        </div>

        {/* ── Footer ──────────────────────────────────────── */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-[var(--outline-v)] flex-shrink-0">
          <button onClick={onClose} disabled={saving} suppressHydrationWarning
            className="px-5 py-2.5 rounded-lg text-[13px] font-medium border border-[var(--outline-v)] text-[var(--on-bg)] bg-white hover:bg-[var(--bg-low)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button onClick={submit} disabled={saving} suppressHydrationWarning
            className="flex items-center gap-2 px-5 py-2.5 rounded-lg text-[13px] font-semibold text-white transition-colors shadow-sm disabled:opacity-60"
            style={{ background: "var(--primary)" }}>
            <i className="ti ti-check text-[15px]" />
            {saving ? "Adding…" : "Add Employee"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Section divider ────────────────────────────────────────── */
function Section({ title, icon }: { title: string; icon: string }) {
  return (
    <div className="flex items-center gap-2 pt-1">
      <div className="w-6 h-6 rounded-md flex items-center justify-center flex-shrink-0"
        style={{ background: "rgba(30,78,140,0.10)" }}>
        <i className={`ti ${icon} text-[13px]`} style={{ color: "var(--primary)" }} />
      </div>
      <span className="text-[12px] font-bold uppercase tracking-wide" style={{ color: "var(--primary)" }}>
        {title}
      </span>
      <div className="flex-1 h-px" style={{ background: "var(--outline-v)" }} />
    </div>
  );
}

/* ── Select wrapper ─────────────────────────────────────────── */
function Sel({ value, onChange, children }: {
  value: string; onChange: (v: string) => void; children: ReactNode;
}) {
  return (
    <select value={value} onChange={e => onChange(e.target.value)} suppressHydrationWarning
      className={`${INPUT} ${B_OK} appearance-none pr-9 cursor-pointer`}
      style={SEL_STYLE}>
      {children}
    </select>
  );
}

/* ── Field wrapper ──────────────────────────────────────────── */
function Field({ label, required, error, children }: {
  label: string; required?: boolean; error?: string; children: ReactNode;
}) {
  return (
    <div>
      <label className={LABEL}>
        {label}
        {required && <span className="ml-0.5 font-bold" style={{ color: "var(--error)" }}>*</span>}
      </label>
      {children}
      {error && <p className="text-[11.5px] mt-1 font-medium" style={{ color: "var(--error)" }}>{error}</p>}
    </div>
  );
}
