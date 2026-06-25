"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Candidate,
  CandidateLog,
  LogType,
  RECRUITMENT_API,
  fmtDate,
  fmtDateTime,
  initials,
} from "../interview-list/_data";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function Avatar({ name, size = 32 }: { name: string; size?: number }) {
  return (
    <div className="user-avatar" style={{ width: size, height: size, fontSize: size * 0.38, flexShrink: 0 }}>
      {initials(name)}
    </div>
  );
}

const LOG_ICON: Record<LogType, string> = {
  success: "ti-check",
  error:   "ti-x",
  info:    "ti-info-circle",
  warn:    "ti-alert-triangle",
};

// ─── HR Decision Modal ────────────────────────────────────────────────────────

interface HRModalProps {
  candidate: Candidate;
  decision:  "approve" | "reject";
  onClose:   () => void;
  onDone:    (updated: Candidate) => void;
}

function HRDecisionModal({ candidate, decision, onClose, onDone }: HRModalProps) {
  const [remarks, setRemarks] = useState("");
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState("");
  const isApprove = decision === "approve";

  async function handleConfirm() {
    setSaving(true);
    setError("");
    try {
      const res = await RECRUITMENT_API.hrDecision(candidate.id, { decision, remarks });
      onDone(res.data.data);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setError(msg || "Action failed.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 480 }}>
        <div className="modal-header">
          <div className="modal-title">{isApprove ? "Approve & Onboard" : "Request Revision"} — {candidate.name}</div>
          <button className="modal-close" onClick={onClose}><i className="ti ti-x" /></button>
        </div>
        <div className="modal-body">
          {error && <div className="alert alert-error mb-16"><i className="ti ti-alert-circle" /><div>{error}</div></div>}
          <div className={`alert ${isApprove ? "alert-success" : "alert-warn"} mb-16`}>
            <i className={`ti ${isApprove ? "ti-check" : "ti-alert-triangle"}`} />
            <div>
              {isApprove
                ? <>Approving <strong>{candidate.name}</strong> will onboard them as an employee and send a welcome email.</>
                : <>A revision request will be sent to <strong>{candidate.name}</strong> to resubmit their details.</>
              }
            </div>
          </div>
          <div className="field-group">
            <label className="field-label">HR Remarks {isApprove ? "(optional)" : "(required)"}</label>
            <input
              className="field-input"
              placeholder={isApprove ? "Any onboarding notes…" : "Specify what needs to be corrected…"}
              value={remarks}
              onChange={e => setRemarks(e.target.value)}
            />
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button
            className={`btn ${isApprove ? "btn-success" : "btn-danger"}`}
            onClick={handleConfirm}
            disabled={saving || (!isApprove && !remarks.trim())}
          >
            {saving
              ? <><i className="ti ti-loader-2 spin" /> Processing…</>
              : isApprove
                ? <><i className="ti ti-check" /> Approve & Onboard</>
                : <><i className="ti ti-alert-triangle" /> Request Revision</>
            }
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Candidate Accordion Item ─────────────────────────────────────────────────

interface AccordionItemProps {
  candidate: Candidate;
  onDecision: (c: Candidate, d: "approve" | "reject") => void;
  onUpdated:  (c: Candidate) => void;
}

function CandidateAccordionItem({ candidate: initial, onDecision }: AccordionItemProps) {
  const [open, setOpen] = useState(false);
  const c = initial;

  const filled   = c.details_filled;
  const approved = c.hr_approved;

  let badge: React.ReactNode;
  if (approved)      badge = <span className="badge badge-success">HR Approved</span>;
  else if (filled)   badge = <span className="badge badge-warn">Details Submitted — Review</span>;
  else               badge = <span className="badge badge-neutral">Awaiting Details</span>;

  const mockDocs = ["Aadhaar Card", "PAN Card", "Degree Certificate", "Offer Letter Signed", "Photograph"];

  return (
    <div className="accordion-item" style={{ marginBottom: 12 }}>
      {/* Header */}
      <div
        className={`accordion-header ${open ? "open" : ""}`}
        onClick={() => setOpen(o => !o)}
        style={{ cursor: "pointer" }}
      >
        <Avatar name={c.name} size={32} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 500 }}>{c.name}</div>
          <div style={{ fontSize: 12, color: "var(--on-variant)" }}>{c.position_applied} • Applied {fmtDate(c.interview_date)}</div>
        </div>
        {badge}
        <i className={`ti ti-chevron-down accordion-toggle ${open ? "rotated" : ""}`} style={{ transition: "transform 0.2s", transform: open ? "rotate(180deg)" : "rotate(0deg)" }} />
      </div>

      {/* Body */}
      {open && (
        <div className="accordion-body">

          {/* ── Details submitted, not yet approved ── */}
          {filled && !approved && (
            <>
              <div className="grid-2 mb-16">
                <div>
                  <div className="settings-card-title mb-8">Personal Details</div>
                  <div style={{ fontSize: 13, lineHeight: 2, color: "var(--on-variant)" }}>
                    <strong style={{ color: "var(--on-bg)" }}>Full Name:</strong> {c.name}<br />
                    <strong style={{ color: "var(--on-bg)" }}>Email:</strong> {c.email}<br />
                    <strong style={{ color: "var(--on-bg)" }}>Phone:</strong> {c.phone || "—"}<br />
                    <strong style={{ color: "var(--on-bg)" }}>Position:</strong> {c.position_applied}
                  </div>
                </div>
                <div>
                  <div className="settings-card-title mb-8">Uploaded Documents</div>
                  {mockDocs.map(d => (
                    <div key={d} style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 0", borderBottom: "1px solid var(--outline-v)" }}>
                      <i className="ti ti-file-check" style={{ color: "var(--success)" }} />
                      <span style={{ fontSize: 13 }}>{d}</span>
                      <button className="btn btn-ghost btn-sm" style={{ marginLeft: "auto" }}><i className="ti ti-eye" /></button>
                    </div>
                  ))}
                </div>
              </div>
              <div style={{ display: "flex", alignItems: "flex-end", gap: 10, flexWrap: "wrap" }}>
                <button className="btn btn-danger" onClick={() => onDecision(c, "reject")}>
                  <i className="ti ti-refresh" /> Request Revision
                </button>
                <button className="btn btn-success" onClick={() => onDecision(c, "approve")}>
                  <i className="ti ti-check" /> Approve & Onboard
                </button>
              </div>
            </>
          )}

          {/* ── Already approved ── */}
          {approved && (
            <div className="alert alert-success">
              <i className="ti ti-check" />
              <div>Approved and onboarded as employee. Welcome email sent.</div>
            </div>
          )}

          {/* ── Still waiting for details ── */}
          {!filled && !approved && (
            <div className="alert alert-info">
              <i className="ti ti-info-circle" />
              <div>Candidate has been selected and emailed login credentials. Waiting for them to fill and submit their details.</div>
            </div>
          )}

          {/* ── Activity log ── */}
          {c.logs && c.logs.length > 0 && (
            <div style={{ marginTop: 16 }}>
              <div className="settings-card-title mb-8"><i className="ti ti-history" style={{ marginRight: 4 }} />Activity Log</div>
              <div className="timeline">
                {c.logs.map((l: CandidateLog) => (
                  <div key={l.id} className="tl-item">
                    <div className={`tl-dot tl-${l.log_type}`}><i className={`ti ${LOG_ICON[l.log_type]}`} /></div>
                    <div className="tl-body">
                      <div className="tl-title">{l.title}</div>
                      {l.description && <div className="tl-desc">{l.description}</div>}
                      <div className="tl-time">{fmtDateTime(l.created_at)}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function CandidateReviewPage() {
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [loading,    setLoading]    = useState(true);
  const [error,      setError]      = useState("");
  const [modal,      setModal]      = useState<{ candidate: Candidate; decision: "approve" | "reject" } | null>(null);

  const fetchReview = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await RECRUITMENT_API.reviewList();
      setCandidates(res.data.data);
    } catch {
      setError("Failed to load candidates for review.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchReview(); }, [fetchReview]);

  function handleDecision(c: Candidate, d: "approve" | "reject") {
    setModal({ candidate: c, decision: d });
  }

  function handleDone(updated: Candidate) {
    setCandidates(prev => prev.map(c => c.id === updated.id ? { ...c, ...updated } : c));
    setModal(null);
  }

  const pendingReview  = candidates.filter(c => c.details_filled && !c.hr_approved).length;
  const awaitingSubmit = candidates.filter(c => !c.details_filled).length;
  const approved       = candidates.filter(c => c.hr_approved).length;

  return (
    <>
      {/* Header */}
      <div className="page-header">
        <div>
          <div className="page-title">Candidate Review</div>
          <div className="page-sub">Review submitted details and approve candidates for employee onboarding</div>
        </div>
      </div>

      {/* Stats row */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 12, marginBottom: 20 }}>
        {[
          { label: "Total Selected",     value: candidates.length, icon: "ti-users",      color: "var(--primary)" },
          { label: "Pending Review",      value: pendingReview,     icon: "ti-eye",        color: "var(--warn)" },
          { label: "Awaiting Submission", value: awaitingSubmit,    icon: "ti-clock",      color: "var(--outline)" },
          { label: "Approved",            value: approved,          icon: "ti-user-check", color: "var(--success)" },
        ].map(s => (
          <div key={s.label} className="card" style={{ padding: "16px 20px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: 8, background: `${s.color}18`, display: "flex", alignItems: "center", justifyContent: "center", color: s.color }}>
                <i className={`ti ${s.icon}`} style={{ fontSize: 18 }} />
              </div>
              <div>
                <div style={{ fontSize: 22, fontWeight: 700, lineHeight: 1 }}>{s.value}</div>
                <div style={{ fontSize: 11, color: "var(--on-variant)", marginTop: 2 }}>{s.label}</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Content */}
      {error && <div className="alert alert-error mb-16"><i className="ti ti-alert-circle" /><div>{error}</div></div>}

      {loading ? (
        <div style={{ padding: 60, textAlign: "center" }}><i className="ti ti-loader-2 spin" style={{ fontSize: 32 }} /></div>
      ) : candidates.length === 0 ? (
        <div className="empty-state">
          <i className="ti ti-user-check" />
          <h3>No pending reviews</h3>
          <p>Selected candidates who have filled their details will appear here.</p>
        </div>
      ) : (
        candidates.map(c => (
          <CandidateAccordionItem
            key={c.id}
            candidate={c}
            onDecision={handleDecision}
            onUpdated={handleDone}
          />
        ))
      )}

      {/* HR Decision Modal */}
      {modal && (
        <HRDecisionModal
          candidate={modal.candidate}
          decision={modal.decision}
          onClose={() => setModal(null)}
          onDone={handleDone}
        />
      )}
    </>
  );
}
