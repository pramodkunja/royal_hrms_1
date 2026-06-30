"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

// ─── Types ────────────────────────────────────────────────────────────────────

interface LeaveType {
  id: number;
  name: string;
  code: string;
  color: string;
  max_days: number;
  carry_forward: boolean;
  carry_forward_limit: number;
  requires_document: boolean;
  is_paid: boolean;
  applicable_gender: "all" | "male" | "female";
  is_active: boolean;
}

// ─── Static seed data ─────────────────────────────────────────────────────────

const SEED: LeaveType[] = [
  { id: 1, name: "Casual Leave",  code: "CL", color: "#1e4e8c", max_days: 12, carry_forward: false, carry_forward_limit: 0,  requires_document: false, is_paid: true,  applicable_gender: "all",    is_active: true  },
  { id: 2, name: "Earned Leave",  code: "EL", color: "#1b8a6b", max_days: 18, carry_forward: true,  carry_forward_limit: 15, requires_document: false, is_paid: true,  applicable_gender: "all",    is_active: true  },
  { id: 3, name: "Sick Leave",    code: "SL", color: "#b5651d", max_days: 6,  carry_forward: false, carry_forward_limit: 0,  requires_document: true,  is_paid: true,  applicable_gender: "all",    is_active: true  },
  { id: 4, name: "Maternity",     code: "ML", color: "#ad95cf", max_days: 84, carry_forward: false, carry_forward_limit: 0,  requires_document: true,  is_paid: true,  applicable_gender: "female", is_active: true  },
  { id: 5, name: "Leave Without Pay", code: "LWP", color: "#6b7280", max_days: 30, carry_forward: false, carry_forward_limit: 0, requires_document: false, is_paid: false, applicable_gender: "all", is_active: true },
];

const BLANK: Omit<LeaveType, "id"> = {
  name: "", code: "", color: "#1e4e8c", max_days: 0,
  carry_forward: false, carry_forward_limit: 0,
  requires_document: false, is_paid: true,
  applicable_gender: "all", is_active: true,
};

function Spin() {
  return <i className="ti ti-loader-2" style={{ animation: "spin 1s linear infinite" }} />;
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function LeavePolicyPage() {
  const router = useRouter();

  const [types,   setTypes]   = useState<LeaveType[]>(SEED);
  const [modal,   setModal]   = useState<"add" | "edit" | null>(null);
  const [editing, setEditing] = useState<LeaveType | null>(null);
  const [form,    setForm]    = useState<Omit<LeaveType, "id">>(BLANK);
  const [errors,  setErrors]  = useState<Record<string, string>>({});
  const [saving,  setSaving]  = useState(false);

  function openAdd() {
    setEditing(null); setForm(BLANK); setErrors({}); setModal("add");
  }
  function openEdit(t: LeaveType) {
    setEditing(t);
    setForm({ name: t.name, code: t.code, color: t.color, max_days: t.max_days, carry_forward: t.carry_forward, carry_forward_limit: t.carry_forward_limit, requires_document: t.requires_document, is_paid: t.is_paid, applicable_gender: t.applicable_gender, is_active: t.is_active });
    setErrors({}); setModal("edit");
  }
  function closeModal() { setModal(null); setEditing(null); }

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!form.name.trim())               e.name     = "Name is required.";
    if (!form.code.trim())               e.code     = "Code is required.";
    if (form.max_days < 1)               e.max_days = "Must be at least 1 day.";
    if (form.carry_forward && form.carry_forward_limit < 1)
      e.carry_forward_limit = "Carry-forward limit must be at least 1.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function save() {
    if (!validate()) return;
    setSaving(true);
    setTimeout(() => {
      if (modal === "add") {
        const next = { ...form, id: Date.now() };
        setTypes(prev => [...prev, next]);
      } else if (editing) {
        setTypes(prev => prev.map(t => t.id === editing.id ? { ...form, id: editing.id } : t));
      }
      setSaving(false);
      closeModal();
    }, 400);
  }

  function toggleActive(id: number) {
    setTypes(prev => prev.map(t => t.id === id ? { ...t, is_active: !t.is_active } : t));
  }

  function remove(id: number) {
    if (!window.confirm("Delete this leave type? This cannot be undone.")) return;
    setTypes(prev => prev.filter(t => t.id !== id));
  }

  function field(key: keyof typeof form, value: string | number | boolean) {
    setErrors(prev => { const n = { ...prev }; delete n[key]; return n; });
    setForm(prev => ({ ...prev, [key]: value }));
  }

  return (
    <>
      <div className="page-header">
        <div>
          <div className="page-title">Leave Policy</div>
          <div className="page-sub">Configure leave types, accruals and entitlement limits</div>
        </div>
        <div className="page-actions">
          <button className="btn btn-ghost" onClick={() => router.push("/dashboard/settings")}>
            <i className="ti ti-arrow-left" /> Back
          </button>
          <button className="btn btn-filled" onClick={openAdd}>
            <i className="ti ti-plus" /> Add Leave Type
          </button>
        </div>
      </div>

      {/* Stats bar */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 1, background: "var(--outline-v)", borderRadius: "var(--radius-lg)", overflow: "hidden", marginBottom: 24 }}>
        {[
          { icon: "ti-beach",        color: "var(--primary)", bg: "rgba(30,78,140,0.08)",  label: "Total Types",    value: types.length },
          { icon: "ti-circle-check", color: "var(--success)", bg: "rgba(27,138,107,0.08)", label: "Active",         value: types.filter(t => t.is_active).length },
          { icon: "ti-cash",         color: "var(--info)",    bg: "rgba(14,124,134,0.08)", label: "Paid Leaves",    value: types.filter(t => t.is_paid).length },
          { icon: "ti-repeat",       color: "var(--warn)",    bg: "rgba(181,101,29,0.08)", label: "Carry Forward",  value: types.filter(t => t.carry_forward).length },
        ].map((s, i) => (
          <div key={i} style={{ background: "var(--surface)", padding: "18px 22px", display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 42, height: 42, borderRadius: 11, background: s.bg, display: "flex", alignItems: "center", justifyContent: "center", color: s.color, flexShrink: 0 }}>
              <i className={`ti ${s.icon}`} style={{ fontSize: 20 }} />
            </div>
            <div>
              <div style={{ fontSize: 24, fontWeight: 700, color: "var(--on-bg)", lineHeight: 1 }}>{s.value}</div>
              <div style={{ fontSize: 12, color: "var(--on-variant)", marginTop: 3 }}>{s.label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="card">
        <div className="card-header">
          <div className="card-title"><i className="ti ti-beach" /> Leave Types</div>
          <span style={{ fontSize: 12, color: "var(--on-variant)" }}>{types.length} configured</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th style={{ textAlign: "center" }}>Code</th>
                <th style={{ textAlign: "center" }}>Max Days</th>
                <th style={{ textAlign: "center" }}>Paid</th>
                <th style={{ textAlign: "center" }}>Carry Fwd</th>
                <th style={{ textAlign: "center" }}>Document</th>
                <th style={{ textAlign: "center" }}>Gender</th>
                <th style={{ textAlign: "center" }}>Status</th>
                <th style={{ textAlign: "center" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {types.map(t => (
                <tr key={t.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div style={{ width: 10, height: 10, borderRadius: "50%", background: t.color, flexShrink: 0 }} />
                      <span style={{ fontWeight: 600, fontSize: 13 }}>{t.name}</span>
                    </div>
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <code style={{ fontSize: 12, background: "var(--bg-low)", padding: "2px 8px", borderRadius: 4, color: "var(--on-variant)" }}>{t.code}</code>
                  </td>
                  <td style={{ textAlign: "center", fontWeight: 600 }}>{t.max_days}</td>
                  <td style={{ textAlign: "center" }}>
                    <span className={`badge ${t.is_paid ? "badge-success" : "badge-neutral"}`}>{t.is_paid ? "Paid" : "Unpaid"}</span>
                  </td>
                  <td style={{ textAlign: "center" }}>
                    {t.carry_forward
                      ? <span className="badge badge-info">Up to {t.carry_forward_limit}d</span>
                      : <span className="badge badge-neutral">No</span>}
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <span className={`badge ${t.requires_document ? "badge-warn" : "badge-neutral"}`}>{t.requires_document ? "Required" : "Optional"}</span>
                  </td>
                  <td style={{ textAlign: "center", textTransform: "capitalize" }}>
                    <span className="badge badge-neutral">{t.applicable_gender}</span>
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <button
                      className="btn btn-ghost"
                      style={{ fontSize: 11, padding: "2px 10px", borderRadius: 20, border: "1px solid var(--outline-v)", color: t.is_active ? "var(--success)" : "var(--outline)" }}
                      onClick={() => toggleActive(t.id)}
                    >
                      {t.is_active ? "Active" : "Inactive"}
                    </button>
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <div style={{ display: "flex", gap: 6, justifyContent: "center" }}>
                      <button className="btn btn-ghost" style={{ width: 28, height: 28, padding: 0, justifyContent: "center", border: "1px solid var(--outline-v)", borderRadius: 6 }} onClick={() => openEdit(t)}>
                        <i className="ti ti-edit" style={{ fontSize: 13 }} />
                      </button>
                      <button className="btn btn-ghost" style={{ width: 28, height: 28, padding: 0, justifyContent: "center", border: "1px solid var(--outline-v)", borderRadius: 6, color: "var(--error)" }} onClick={() => remove(t.id)}>
                        <i className="ti ti-trash" style={{ fontSize: 13 }} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {modal && (
        <div className="modal-overlay open">
          <div className="modal" style={{ maxWidth: 540 }}>
            <div className="modal-header">
              <div className="modal-title">
                <i className="ti ti-beach" style={{ marginRight: 8 }} />
                {modal === "add" ? "Add Leave Type" : `Edit: ${editing?.name}`}
              </div>
              <button className="modal-close" onClick={closeModal}><i className="ti ti-x" /></button>
            </div>
            <div className="modal-body">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0 16px" }}>
                {/* Name */}
                <div className="field-group mb-16" style={{ gridColumn: "1 / -1" }}>
                  <label className="field-label">Leave Type Name *</label>
                  <input className={`field-input${errors.name ? " field-error" : ""}`} value={form.name} onChange={e => field("name", e.target.value)} placeholder="e.g. Casual Leave" autoFocus maxLength={60} />
                  {errors.name && <p className="field-error-msg">{errors.name}</p>}
                </div>
                {/* Code */}
                <div className="field-group mb-16">
                  <label className="field-label">Short Code *</label>
                  <input className={`field-input${errors.code ? " field-error" : ""}`} value={form.code} onChange={e => field("code", e.target.value.toUpperCase())} placeholder="CL" maxLength={6} />
                  {errors.code && <p className="field-error-msg">{errors.code}</p>}
                </div>
                {/* Color */}
                <div className="field-group mb-16">
                  <label className="field-label">Colour</label>
                  <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <input type="color" value={form.color} onChange={e => field("color", e.target.value)} style={{ width: 40, height: 36, border: "1px solid var(--outline-v)", borderRadius: 6, cursor: "pointer", padding: 2 }} />
                    <code style={{ fontSize: 12, color: "var(--on-variant)" }}>{form.color}</code>
                  </div>
                </div>
                {/* Max days */}
                <div className="field-group mb-16">
                  <label className="field-label">Max Days / Year *</label>
                  <input className={`field-input${errors.max_days ? " field-error" : ""}`} type="number" min={1} value={form.max_days} onChange={e => field("max_days", Number(e.target.value))} />
                  {errors.max_days && <p className="field-error-msg">{errors.max_days}</p>}
                </div>
                {/* Gender */}
                <div className="field-group mb-16">
                  <label className="field-label">Applicable Gender</label>
                  <select className="field-input" value={form.applicable_gender} onChange={e => field("applicable_gender", e.target.value)}>
                    <option value="all">All</option>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                  </select>
                </div>
              </div>

              {/* Carry forward */}
              <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 14 }}>
                <label className="module-check" style={{ flex: 1 }}>
                  <input type="checkbox" checked={form.carry_forward} onChange={e => field("carry_forward", e.target.checked)} />
                  <span>Allow Carry Forward</span>
                </label>
                {form.carry_forward && (
                  <div className="field-group" style={{ width: 140 }}>
                    <label className="field-label">Max Carry Fwd Days *</label>
                    <input className={`field-input${errors.carry_forward_limit ? " field-error" : ""}`} type="number" min={1} value={form.carry_forward_limit} onChange={e => field("carry_forward_limit", Number(e.target.value))} />
                    {errors.carry_forward_limit && <p className="field-error-msg">{errors.carry_forward_limit}</p>}
                  </div>
                )}
              </div>

              <div style={{ display: "flex", gap: 24, flexWrap: "wrap", marginBottom: 4 }}>
                <label className="module-check">
                  <input type="checkbox" checked={form.is_paid} onChange={e => field("is_paid", e.target.checked)} />
                  <span>Paid Leave</span>
                </label>
                <label className="module-check">
                  <input type="checkbox" checked={form.requires_document} onChange={e => field("requires_document", e.target.checked)} />
                  <span>Requires Medical Certificate</span>
                </label>
                <label className="module-check">
                  <input type="checkbox" checked={form.is_active} onChange={e => field("is_active", e.target.checked)} />
                  <span>Active</span>
                </label>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={closeModal}>Cancel</button>
              <button className="btn btn-filled" onClick={save} disabled={saving}>
                {saving ? <><Spin />&nbsp;Saving…</> : modal === "add" ? "Create Leave Type" : "Save Changes"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
