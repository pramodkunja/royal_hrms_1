"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import clientApi from "@/lib/clientApi";
import { API } from "@/lib/api/endpoints";
import { getStoredUser, setOnboardingStatus } from "@/lib/auth";

// ── Types ─────────────────────────────────────────────────────────────────────

interface ProfileForm {
  date_of_birth: string; gender: string; marital_status: string;
  father_name: string; blood_group: string;
  current_address: string; permanent_address: string;
  highest_qualification: string; institution: string;
  year_of_passing: string; specialization: string;
  total_experience_years: string; previous_employer: string;
  previous_designation: string; leaving_reason: string;
  account_number: string; ifsc_code: string; bank_name: string;
  bank_branch_name: string; account_holder_name: string; account_type: string;
  emergency_name: string; emergency_relationship: string;
  emergency_phone: string; emergency_email: string;
}

interface UploadedDoc { id: number; document_type: string; document_type_display: string; file_name: string; uploaded_at: string; }

const EMPTY: ProfileForm = {
  date_of_birth: "", gender: "", marital_status: "", father_name: "", blood_group: "",
  current_address: "", permanent_address: "",
  highest_qualification: "", institution: "", year_of_passing: "", specialization: "",
  total_experience_years: "", previous_employer: "", previous_designation: "", leaving_reason: "",
  account_number: "", ifsc_code: "", bank_name: "", bank_branch_name: "",
  account_holder_name: "", account_type: "",
  emergency_name: "", emergency_relationship: "", emergency_phone: "", emergency_email: "",
};

const TABS = ["Personal", "Education & Experience", "Bank Details", "Emergency Contact", "Documents"];
const DOC_TYPES = [
  { value: "pan_card",           label: "PAN Card" },
  { value: "aadhaar_card",       label: "Aadhaar Card" },
  { value: "degree_certificate", label: "Degree Certificate" },
  { value: "experience_letter",  label: "Experience Letter" },
];

const INP = "field-input";
const SEL = "field-input";

// ── Component ─────────────────────────────────────────────────────────────────

export default function OnboardingPage() {
  const [tab,      setTab]      = useState(0);
  const [form,     setForm]     = useState<ProfileForm>(EMPTY);
  const [docs,     setDocs]     = useState<UploadedDoc[]>([]);
  const [saving,   setSaving]   = useState(false);
  const [saveMsg,  setSaveMsg]  = useState<string | null>(null);
  const [saveErr,  setSaveErr]  = useState<string | null>(null);
  const [uploading, setUploading] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [draftStatus, setDraftStatus] = useState<"idle" | "saving" | "saved">("idle");

  // Always-current copy of form for use inside timer callbacks
  const formRef       = useRef<ProfileForm>(EMPTY);
  const isDirty       = useRef(false);
  const autoSaveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fileRefs      = useRef<Record<string, HTMLInputElement | null>>({});

  const user = getStoredUser();
  const isAlreadySubmitted = user?.onboarding_status === "submitted";

  // Keep formRef in sync so auto-save always captures the latest values
  useEffect(() => { formRef.current = form; }, [form]);

  useEffect(() => {
    clientApi.get(API.onboarding.profile).then(r => {
      const d = r.data?.data ?? {};
      setForm(prev => ({ ...prev, ...Object.fromEntries(
        Object.keys(EMPTY).map(k => [k, d[k] ?? ""])
      ) }));
    }).catch(() => {});
    clientApi.get(API.onboarding.documents).then(r => {
      setDocs(r.data?.data ?? []);
    }).catch(() => {});
  }, []);

  // Warn before tab/window close if there are unsaved changes
  useEffect(() => {
    function handleBeforeUnload(e: BeforeUnloadEvent) {
      if (isDirty.current) {
        e.preventDefault();
      }
    }
    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, []);

  // Clean up pending timer on unmount
  useEffect(() => {
    return () => {
      if (autoSaveTimer.current) clearTimeout(autoSaveTimer.current);
    };
  }, []);

  // Silent auto-save — does not touch saveMsg / saveErr
  const autoSave = useCallback(async () => {
    if (!isDirty.current) return;
    setDraftStatus("saving");
    try {
      await clientApi.patch(API.onboarding.profile, formRef.current);
      isDirty.current = false;
      setDraftStatus("saved");
      setTimeout(() => setDraftStatus("idle"), 3000);
    } catch {
      setDraftStatus("idle");
    }
  }, []);

  function set(field: keyof ProfileForm, value: string) {
    setForm(prev => ({ ...prev, [field]: value }));
    isDirty.current = true;
    setDraftStatus("idle");
    if (autoSaveTimer.current) clearTimeout(autoSaveTimer.current);
    autoSaveTimer.current = setTimeout(autoSave, 1500);
  }

  async function saveSection() {
    // Cancel any pending auto-save — this manual save supersedes it
    if (autoSaveTimer.current) {
      clearTimeout(autoSaveTimer.current);
      autoSaveTimer.current = null;
    }
    isDirty.current = false;
    setDraftStatus("idle");
    setSaving(true); setSaveMsg(null); setSaveErr(null);
    try {
      await clientApi.patch(API.onboarding.profile, formRef.current);
      setSaveMsg("Saved.");
      setTimeout(() => setSaveMsg(null), 2000);
    } catch {
      setSaveErr("Save failed. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  async function next() {
    await saveSection();
    if (tab < TABS.length - 1) setTab(t => t + 1);
  }

  async function handleUpload(docType: string, file: File) {
    setUploading(docType);
    const fd = new FormData();
    fd.append("document_type", docType);
    fd.append("file", file);
    try {
      await clientApi.post(API.onboarding.documents, fd, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      const r = await clientApi.get(API.onboarding.documents);
      setDocs(r.data?.data ?? []);
    } catch {
      setSaveErr("Upload failed. Max 5 MB, PDF/JPG/PNG only.");
    } finally {
      setUploading(null);
    }
  }

  async function handleSubmit() {
    await saveSection();
    setSaving(true);
    try {
      await clientApi.post(API.onboarding.submit, {});
      setOnboardingStatus("submitted");
      setSubmitted(true);
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { message?: string } } })
        ?.response?.data?.message ?? "Submission failed.";
      setSaveErr(msg);
    } finally {
      setSaving(false);
    }
  }

  const uploadedTypes = new Set(docs.map(d => d.document_type));

  // ── Submitted / waiting screen ─────────────────────────────────────────────
  if (submitted || isAlreadySubmitted) {
    return (
      <div className="onboarding-root">
        <div className="onboarding-card">
          <div style={{ textAlign: "center", padding: "2.5rem 1rem" }}>
            <div style={{ fontSize: "3rem", marginBottom: "1rem" }}>✅</div>
            <h2 className="card-title" style={{ marginBottom: ".5rem" }}>Profile Submitted</h2>
            <p style={{ color: "var(--text-secondary)", marginBottom: "1.5rem" }}>
              Your onboarding details have been sent for HR review.<br />
              You will receive access to the dashboard once approved.
            </p>
            <p style={{ fontSize: ".85rem", color: "var(--text-muted)" }}>
              You can close this tab. We will notify you by email when approved.
            </p>
          </div>
        </div>
      </div>
    );
  }

  // ── Wizard ─────────────────────────────────────────────────────────────────
  return (
    <div className="onboarding-root">
      {/* Header */}
      <div className="onboarding-header">
        <div className="login-brand-icon" style={{ marginBottom: ".25rem" }}>👑</div>
        <h1 className="onboarding-title">Complete Your Profile</h1>
        <p className="onboarding-subtitle">Fill in your details to get started. Your information is kept secure.</p>
      </div>

      {/* Step tabs */}
      <div className="onboarding-steps">
        {TABS.map((t, i) => (
          <button
            key={t}
            className={`onboarding-step${i === tab ? " onboarding-step--active" : i < tab ? " onboarding-step--done" : ""}`}
            onClick={() => setTab(i)}
            type="button"
          >
            <span className="onboarding-step-num">{i < tab ? "✓" : i + 1}</span>
            <span className="onboarding-step-label">{t}</span>
          </button>
        ))}
      </div>

      {/* Card */}
      <div className="onboarding-card">
        {saveErr  && <div className="alert alert-error"  style={{ marginBottom: "1rem" }}>{saveErr}</div>}
        {saveMsg  && <div className="alert alert-success" style={{ marginBottom: "1rem" }}>{saveMsg}</div>}

        {tab === 0 && <TabPersonal  form={form} set={set} />}
        {tab === 1 && <TabEducation form={form} set={set} />}
        {tab === 2 && <TabBank      form={form} set={set} />}
        {tab === 3 && <TabEmergency form={form} set={set} />}
        {tab === 4 && (
          <TabDocuments
            docs={docs}
            uploadedTypes={uploadedTypes}
            uploading={uploading}
            fileRefs={fileRefs}
            onUpload={handleUpload}
          />
        )}

        {/* Navigation */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "1.5rem", paddingTop: "1rem", borderTop: "1px solid var(--border)" }}>
          <button
            className="btn btn-ghost"
            onClick={() => setTab(t => t - 1)}
            disabled={tab === 0 || saving}
            type="button"
          >
            ← Previous
          </button>

          {/* Auto-save status indicator */}
          <span style={{ fontSize: ".8rem", color: "var(--text-muted)", flex: 1, textAlign: "center" }}>
            {draftStatus === "saving" && "Saving draft…"}
            {draftStatus === "saved"  && "✓ Draft saved"}
          </span>

          {tab < TABS.length - 1 ? (
            <button className="btn btn-filled" onClick={next} disabled={saving} type="button">
              {saving ? "Saving…" : "Save & Continue →"}
            </button>
          ) : (
            <div style={{ display: "flex", gap: ".75rem" }}>
              <button className="btn btn-ghost" onClick={saveSection} disabled={saving} type="button">
                {saving ? "Saving…" : "Save Draft"}
              </button>
              <button className="btn btn-filled" onClick={handleSubmit} disabled={saving} type="button">
                {saving ? "Submitting…" : "Submit for Approval ✓"}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ── Tab: Personal ─────────────────────────────────────────────────────────────

function TabPersonal({ form, set }: { form: ProfileForm; set: (f: keyof ProfileForm, v: string) => void }) {
  return (
    <div>
      <h3 className="card-title" style={{ marginBottom: "1rem" }}>Personal Details</h3>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Date of Birth</label>
          <input type="date" className={INP} value={form.date_of_birth} onChange={e => set("date_of_birth", e.target.value)} />
        </div>
        <div className="field-group">
          <label className="field-label">Gender</label>
          <select className={SEL} value={form.gender} onChange={e => set("gender", e.target.value)}>
            <option value="">Select</option>
            <option value="male">Male</option>
            <option value="female">Female</option>
            <option value="other">Other / Prefer not to say</option>
          </select>
        </div>
        <div className="field-group">
          <label className="field-label">Marital Status</label>
          <select className={SEL} value={form.marital_status} onChange={e => set("marital_status", e.target.value)}>
            <option value="">Select</option>
            <option value="single">Single</option>
            <option value="married">Married</option>
            <option value="divorced">Divorced</option>
            <option value="widowed">Widowed</option>
          </select>
        </div>
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Father&apos;s Name</label>
          <input className={INP} value={form.father_name} onChange={e => set("father_name", e.target.value)} placeholder="Father's full name" />
        </div>
        <div className="field-group">
          <label className="field-label">Blood Group</label>
          <select className={SEL} value={form.blood_group} onChange={e => set("blood_group", e.target.value)}>
            <option value="">Select</option>
            {["A+","A-","B+","B-","O+","O-","AB+","AB-"].map(g => <option key={g} value={g}>{g}</option>)}
          </select>
        </div>
      </div>
      <div className="field-group">
        <label className="field-label">Current Address</label>
        <textarea className={INP} rows={2} value={form.current_address} onChange={e => set("current_address", e.target.value)} placeholder="House / Flat no., Street, City, State, PIN" />
      </div>
      <div className="field-group">
        <label className="field-label">Permanent Address <span style={{ color: "var(--text-muted)", fontWeight: 400 }}>(if different from current)</span></label>
        <textarea className={INP} rows={2} value={form.permanent_address} onChange={e => set("permanent_address", e.target.value)} placeholder="Leave blank if same as current" />
      </div>
    </div>
  );
}

// ── Tab: Education & Experience ───────────────────────────────────────────────

function TabEducation({ form, set }: { form: ProfileForm; set: (f: keyof ProfileForm, v: string) => void }) {
  return (
    <div>
      <h3 className="card-title" style={{ marginBottom: "1rem" }}>Education</h3>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Highest Qualification</label>
          <input className={INP} value={form.highest_qualification} onChange={e => set("highest_qualification", e.target.value)} placeholder="e.g. B.Tech, MBA, B.Com" />
        </div>
        <div className="field-group">
          <label className="field-label">Specialization</label>
          <input className={INP} value={form.specialization} onChange={e => set("specialization", e.target.value)} placeholder="e.g. Computer Science" />
        </div>
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Institution / University</label>
          <input className={INP} value={form.institution} onChange={e => set("institution", e.target.value)} placeholder="College or university name" />
        </div>
        <div className="field-group">
          <label className="field-label">Year of Passing</label>
          <input type="number" className={INP} value={form.year_of_passing} onChange={e => set("year_of_passing", e.target.value)} placeholder="e.g. 2020" min={1950} max={2099} />
        </div>
      </div>

      <h3 className="card-title" style={{ margin: "1.5rem 0 1rem" }}>Work Experience</h3>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Total Experience (years)</label>
          <input type="number" className={INP} value={form.total_experience_years} onChange={e => set("total_experience_years", e.target.value)} placeholder="e.g. 3.5" step="0.1" min={0} />
        </div>
        <div className="field-group">
          <label className="field-label">Previous Employer</label>
          <input className={INP} value={form.previous_employer} onChange={e => set("previous_employer", e.target.value)} placeholder="Company name (if any)" />
        </div>
        <div className="field-group">
          <label className="field-label">Previous Designation</label>
          <input className={INP} value={form.previous_designation} onChange={e => set("previous_designation", e.target.value)} placeholder="Job title (if any)" />
        </div>
      </div>
      <div className="field-group">
        <label className="field-label">Reason for Leaving</label>
        <textarea className={INP} rows={2} value={form.leaving_reason} onChange={e => set("leaving_reason", e.target.value)} placeholder="Optional" />
      </div>
    </div>
  );
}

// ── Tab: Bank Details ─────────────────────────────────────────────────────────

function TabBank({ form, set }: { form: ProfileForm; set: (f: keyof ProfileForm, v: string) => void }) {
  return (
    <div>
      <h3 className="card-title" style={{ marginBottom: "1rem" }}>Bank Details</h3>
      <div className="alert alert-error" style={{ background: "#fff8e1", border: "1px solid #ffc107", color: "#7c5800", marginBottom: "1rem" }}>
        ⚠ Bank details are used for payroll. Ensure all information is accurate and matches your passbook.
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Account Holder Name</label>
          <input className={INP} value={form.account_holder_name} onChange={e => set("account_holder_name", e.target.value)} placeholder="As printed on passbook" />
        </div>
        <div className="field-group">
          <label className="field-label">Account Type</label>
          <select className={SEL} value={form.account_type} onChange={e => set("account_type", e.target.value)}>
            <option value="">Select</option>
            <option value="savings">Savings</option>
            <option value="current">Current</option>
          </select>
        </div>
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Account Number</label>
          <input className={INP} value={form.account_number} onChange={e => set("account_number", e.target.value)} placeholder="Bank account number" />
        </div>
        <div className="field-group">
          <label className="field-label">IFSC Code</label>
          <input className={INP} value={form.ifsc_code} onChange={e => set("ifsc_code", e.target.value.toUpperCase())} placeholder="e.g. SBIN0001234" maxLength={11} />
        </div>
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Bank Name</label>
          <input className={INP} value={form.bank_name} onChange={e => set("bank_name", e.target.value)} placeholder="e.g. State Bank of India" />
        </div>
        <div className="field-group">
          <label className="field-label">Branch Name</label>
          <input className={INP} value={form.bank_branch_name} onChange={e => set("bank_branch_name", e.target.value)} placeholder="Branch city / locality" />
        </div>
      </div>
    </div>
  );
}

// ── Tab: Emergency Contact ────────────────────────────────────────────────────

function TabEmergency({ form, set }: { form: ProfileForm; set: (f: keyof ProfileForm, v: string) => void }) {
  return (
    <div>
      <h3 className="card-title" style={{ marginBottom: "1rem" }}>Emergency Contact</h3>
      <p style={{ color: "var(--text-secondary)", marginBottom: "1rem", fontSize: ".9rem" }}>
        This person will be contacted in case of an emergency at the workplace.
      </p>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Contact Name</label>
          <input className={INP} value={form.emergency_name} onChange={e => set("emergency_name", e.target.value)} placeholder="Full name" />
        </div>
        <div className="field-group">
          <label className="field-label">Relationship</label>
          <input className={INP} value={form.emergency_relationship} onChange={e => set("emergency_relationship", e.target.value)} placeholder="e.g. Spouse, Parent, Sibling" />
        </div>
      </div>
      <div className="field-group-row">
        <div className="field-group">
          <label className="field-label">Phone Number</label>
          <input className={INP} value={form.emergency_phone} onChange={e => set("emergency_phone", e.target.value)} placeholder="Mobile number" />
        </div>
        <div className="field-group">
          <label className="field-label">Email <span style={{ color: "var(--text-muted)", fontWeight: 400 }}>(optional)</span></label>
          <input type="email" className={INP} value={form.emergency_email} onChange={e => set("emergency_email", e.target.value)} placeholder="email@example.com" />
        </div>
      </div>
    </div>
  );
}

// ── Tab: Documents ────────────────────────────────────────────────────────────

function TabDocuments({
  docs, uploadedTypes, uploading, fileRefs, onUpload,
}: {
  docs: UploadedDoc[];
  uploadedTypes: Set<string>;
  uploading: string | null;
  fileRefs: React.RefObject<Record<string, HTMLInputElement | null>>;
  onUpload: (docType: string, file: File) => void;
}) {
  return (
    <div>
      <h3 className="card-title" style={{ marginBottom: "1rem" }}>Documents</h3>
      <p style={{ color: "var(--text-secondary)", marginBottom: "1rem", fontSize: ".9rem" }}>
        Upload clear scans or photos. Accepted formats: PDF, JPG, PNG. Max 5 MB each.
      </p>
      <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
        {DOC_TYPES.map(dt => {
          const uploaded = uploadedTypes.has(dt.value);
          const uploaded_doc = docs.find(d => d.document_type === dt.value);
          const isUploading  = uploading === dt.value;
          return (
            <div key={dt.value} className="card" style={{ padding: "1rem", display: "flex", alignItems: "center", justifyContent: "space-between", gap: "1rem" }}>
              <div>
                <div style={{ fontWeight: 600, marginBottom: ".15rem" }}>{dt.label}</div>
                {uploaded && uploaded_doc && (
                  <div style={{ fontSize: ".8rem", color: "var(--text-secondary)" }}>
                    ✓ {uploaded_doc.file_name}
                  </div>
                )}
              </div>
              <div style={{ display: "flex", gap: ".5rem", alignItems: "center" }}>
                {uploaded && <span style={{ color: "var(--success)", fontSize: ".85rem" }}>Uploaded</span>}
                <input
                  type="file"
                  accept=".pdf,.jpg,.jpeg,.png"
                  style={{ display: "none" }}
                  ref={el => { fileRefs.current[dt.value] = el; }}
                  onChange={e => {
                    const file = e.target.files?.[0];
                    if (file) onUpload(dt.value, file);
                    e.target.value = "";
                  }}
                />
                <button
                  className="btn btn-ghost"
                  style={{ fontSize: ".85rem" }}
                  onClick={() => fileRefs.current[dt.value]?.click()}
                  disabled={isUploading}
                  type="button"
                >
                  {isUploading ? "Uploading…" : uploaded ? "Replace" : "Upload"}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
