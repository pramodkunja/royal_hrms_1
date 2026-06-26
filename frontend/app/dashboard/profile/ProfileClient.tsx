"use client";

import { useState } from "react";
import clientApi from "@/lib/clientApi";
import { API } from "@/lib/api/endpoints";
import type { SessionPayload } from "@/lib/session";

const DOCUMENTS = ["Aadhaar Card", "PAN Card", "Degree Certificate", "Offer Letter"];

function initials(name: string) {
  return name.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2);
}

export default function ProfileClient({ session }: { session: SessionPayload }) {
  const nameParts = session.name.split(" ");

  const [firstName, setFirstName] = useState(nameParts[0] ?? "");
  const [lastName,  setLastName]  = useState(nameParts.slice(1).join(" ") ?? "");
  const [phone,     setPhone]     = useState("");
  const [street,    setStreet]    = useState("");
  const [city,      setCity]      = useState("");
  const [pin,       setPin]       = useState("");
  const [state,     setState]     = useState("");
  const [country,   setCountry]   = useState("");
  const [bankName,  setBankName]  = useState("");
  const [account,   setAccount]   = useState("");
  const [ifsc,      setIfsc]      = useState("");
  const [pan,       setPan]       = useState("");
  const [oldPwd,     setOldPwd]     = useState("");
  const [newPwd,     setNewPwd]     = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [pwdLoading, setPwdLoading] = useState(false);
  const [pwdError,   setPwdError]   = useState("");
  const [pwdSuccess, setPwdSuccess] = useState(false);

  const [toast, setToast] = useState<{ msg: string; type: "success" | "error" } | null>(null);

  function showToast(msg: string, type: "success" | "error" = "success") {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  }

  function handleSave() { showToast("Profile updated successfully"); }

  async function handleChangePassword(e: React.FormEvent) {
    e.preventDefault();
    setPwdError(""); setPwdSuccess(false);
    if (!oldPwd)               { setPwdError("Enter your current password."); return; }
    if (!newPwd)               { setPwdError("Enter a new password."); return; }
    if (newPwd !== confirmPwd) { setPwdError("Passwords do not match."); return; }
    if (newPwd === oldPwd)     { setPwdError("New password must differ from current."); return; }
    setPwdLoading(true);
    try {
      await clientApi.post(API.auth.changePassword, { old_password: oldPwd, new_password: newPwd, confirm_password: confirmPwd });
      setPwdSuccess(true);
      setOldPwd(""); setNewPwd(""); setConfirmPwd("");
      showToast("Password changed successfully");
    } catch (err) {
      const { message } = err as { message: string };
      setPwdError(message || "Failed to change password. Please try again.");
    } finally { setPwdLoading(false); }
  }

  const ini = initials(session.name);

  return (
    <div>
      {/* Toast */}
      {toast && (
        <div className="fixed bottom-6 right-6 z-[9999]">
          <div className="flex items-center gap-2.5 px-[18px] py-3 bg-white rounded-[var(--radius)] min-w-[260px] text-sm font-medium"
            style={{
              boxShadow: "var(--shadow-md)",
              borderLeft: `3px solid ${toast.type === "success" ? "var(--success)" : "var(--error)"}`,
              color: toast.type === "success" ? "var(--success)" : "var(--error)",
              animation: "slideInRight 0.25s ease",
            }}>
            <i className={`ti ${toast.type === "success" ? "ti-circle-check" : "ti-alert-circle"} text-base flex-shrink-0`} />
            {toast.msg}
          </div>
        </div>
      )}

      {/* Page header */}
      <div className="page-header">
        <div>
          <div className="page-title">My Profile</div>
          <div className="page-sub">View and update your personal information</div>
        </div>
        <div className="page-actions">
          <button className="btn btn-filled" onClick={handleSave} suppressHydrationWarning>
            <i className="ti ti-device-floppy" /> Save Changes
          </button>
        </div>
      </div>

      {/* Two-column grid */}
      <div className="grid-2">

        {/* ═══ LEFT COLUMN ═══ */}
        <div>
          {/* Personal Information */}
          <div className="card mb-16">
            <div className="card-header">
              <span className="card-title"><i className="ti ti-user-circle" />Personal Information</span>
            </div>
            <div className="card-body">
              {/* Avatar row */}
              <div className="flex items-center gap-4 mb-5">
                <div className="w-16 h-16 rounded-full bg-[var(--primary)] text-white flex items-center justify-center text-[22px] font-bold flex-shrink-0"
                  style={{ letterSpacing: "-0.01em" }}>
                  {ini}
                </div>
                <div>
                  <div className="text-lg font-bold text-[var(--on-bg)]" style={{ letterSpacing: "-0.01em" }}>{session.name}</div>
                  <div className="text-[13px] text-[var(--on-variant)] mt-0.5">{session.role}</div>
                  <button className="btn btn-ghost btn-sm mt-1.5" suppressHydrationWarning>
                    <i className="ti ti-upload" /> Change photo
                  </button>
                </div>
              </div>

              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">First Name</label>
                  <input className="field-input" value={firstName} onChange={e => setFirstName(e.target.value)} suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">Last Name</label>
                  <input className="field-input" value={lastName} onChange={e => setLastName(e.target.value)} suppressHydrationWarning />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">Email</label>
                  <input className="field-input" value={session.email} disabled suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">Phone</label>
                  <input className="field-input" value={phone} onChange={e => setPhone(e.target.value)} placeholder="+91 98765 43210" suppressHydrationWarning />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">Role</label>
                  <input className="field-input" value={session.role} disabled suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">User ID</label>
                  <input className="field-input" value={session.userId} disabled style={{ fontFamily: "ui-monospace, monospace", fontSize: 12 }} suppressHydrationWarning />
                </div>
              </div>
            </div>
          </div>

          {/* Change Password */}
          <div className="card">
            <div className="card-header">
              <span className="card-title"><i className="ti ti-lock" />Change Password</span>
            </div>
            <div className="card-body">
              <form onSubmit={handleChangePassword} noValidate>
                <div className="form-row">
                  <div className="field-group">
                    <label className="field-label">Current Password</label>
                    <input className="field-input" type="password" placeholder="••••••••"
                      value={oldPwd} onChange={e => setOldPwd(e.target.value)} autoComplete="current-password" suppressHydrationWarning />
                  </div>
                </div>
                <div className="form-row cols-2">
                  <div className="field-group">
                    <label className="field-label">New Password</label>
                    <input className="field-input" type="password" placeholder="••••••••"
                      value={newPwd} onChange={e => setNewPwd(e.target.value)} autoComplete="new-password" suppressHydrationWarning />
                  </div>
                  <div className="field-group">
                    <label className="field-label">Confirm Password</label>
                    <input className="field-input" type="password" placeholder="••••••••"
                      value={confirmPwd} onChange={e => setConfirmPwd(e.target.value)} autoComplete="new-password" suppressHydrationWarning />
                  </div>
                </div>
                {pwdError && <div className="alert alert-error" style={{ marginBottom: 12 }}><i className="ti ti-alert-circle" /> {pwdError}</div>}
                {pwdSuccess && <div className="alert alert-success" style={{ marginBottom: 12 }}><i className="ti ti-circle-check" /> Password changed successfully.</div>}
                <button type="submit" className="btn btn-outline" disabled={pwdLoading} suppressHydrationWarning>
                  <i className="ti ti-lock" />
                  {pwdLoading ? "Updating…" : "Update Password"}
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* ═══ RIGHT COLUMN ═══ */}
        <div>
          {/* Address */}
          <div className="card mb-16">
            <div className="card-header">
              <span className="card-title"><i className="ti ti-map-pin" />Address</span>
            </div>
            <div className="card-body">
              <div className="form-row">
                <div className="field-group">
                  <label className="field-label">Street Address</label>
                  <input className="field-input" value={street} onChange={e => setStreet(e.target.value)} placeholder="e.g. 42, 3rd Cross, HSR Layout" suppressHydrationWarning />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">City</label>
                  <input className="field-input" value={city} onChange={e => setCity(e.target.value)} placeholder="City" suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">PIN Code</label>
                  <input className="field-input" value={pin} onChange={e => setPin(e.target.value)} placeholder="PIN Code" suppressHydrationWarning />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">State</label>
                  <input className="field-input" value={state} onChange={e => setState(e.target.value)} placeholder="State" suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">Country</label>
                  <input className="field-input" value={country} onChange={e => setCountry(e.target.value)} placeholder="Country" suppressHydrationWarning />
                </div>
              </div>
            </div>
          </div>

          {/* Bank Details */}
          <div className="card mb-16">
            <div className="card-header">
              <span className="card-title"><i className="ti ti-building-bank" />Bank Details</span>
            </div>
            <div className="card-body">
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">Bank Name</label>
                  <input className="field-input" value={bankName} onChange={e => setBankName(e.target.value)} placeholder="e.g. HDFC Bank" suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">Account Number</label>
                  <input className="field-input" value={account} onChange={e => setAccount(e.target.value)} placeholder="Account number" suppressHydrationWarning />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="field-group">
                  <label className="field-label">IFSC Code</label>
                  <input className="field-input" value={ifsc} onChange={e => setIfsc(e.target.value)} placeholder="e.g. HDFC0001234" suppressHydrationWarning />
                </div>
                <div className="field-group">
                  <label className="field-label">PAN Number</label>
                  <input className="field-input" value={pan} onChange={e => setPan(e.target.value)} placeholder="e.g. ABCDE1234F" suppressHydrationWarning />
                </div>
              </div>
            </div>
          </div>

          {/* Documents */}
          <div className="card">
            <div className="card-header">
              <span className="card-title"><i className="ti ti-file-description" />Documents</span>
            </div>
            <div className="card-body" style={{ padding: 0 }}>
              {DOCUMENTS.map((doc, i) => (
                <div key={doc} className="flex items-center gap-2.5 px-4 py-2.5"
                  style={{ borderBottom: i < DOCUMENTS.length - 1 ? "1px solid var(--bg-high)" : "none" }}>
                  <i className="ti ti-file-check text-base flex-shrink-0" style={{ color: "var(--success)" }} />
                  <span className="flex-1 text-[13px] text-[var(--on-bg)]">{doc}</span>
                  <button className="btn btn-ghost btn-sm" suppressHydrationWarning><i className="ti ti-eye" /></button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <style>{`@keyframes slideInRight { from { transform: translateX(40px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }`}</style>
    </div>
  );
}
