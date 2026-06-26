"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  Candidate,
  CandidateStatus,
  InterviewMode,
  RECRUITMENT_API,
  RecruitmentStats,
  fmtDate,
  fmtDateTime,
  initials,
  MODE_LABELS,
  CandidateLog,
  LogType,
} from "./_data";

// ─── Tiny helpers ─────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: CandidateStatus }) {
  if (status === "selected")
    return <span className="badge badge-success"><i className="ti ti-check" /> Selected</span>;
  if (status === "rejected")
    return <span className="badge badge-error"><i className="ti ti-x" /> Rejected</span>;
  return <span className="badge badge-neutral"><i className="ti ti-clock" /> Pending</span>;
}

function Avatar({ name, size = 32 }: { name: string; size?: number }) {
  return (
    <div
      className="user-avatar"
      style={{ width: size, height: size, fontSize: size * 0.38, flexShrink: 0 }}
    >
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

// ─── Add Candidate Modal ──────────────────────────────────────────────────────

interface AddModalProps {
  onClose: () => void;
  onSaved: (c: Candidate) => void;
}

function AddCandidateModal({ onClose, onSaved }: AddModalProps) {
  const [form, setForm] = useState<{
    name: string; email: string; phone: string; position_applied: string;
    interview_date: string; interview_mode: InterviewMode; notes: string;
  }>({
    name: "", email: "", phone: "", position_applied: "",
    interview_date: "", interview_mode: "in_person", notes: "",
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState("");

  function set(key: string, val: string) {
    setForm(f => ({ ...f, [key]: val }));
  }

  async function handleSave() {
    if (!form.name.trim() || !form.email.trim() || !form.position_applied.trim()) {
      setError("Name, email and position are required.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const res = await RECRUITMENT_API.create(form);
      onSaved(res.data.data);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setError(msg || "Failed to add candidate.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay open" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 560 }}>
        <div className="modal-header">
          <div className="modal-title">Add Candidate to Interview List</div>
          <button className="modal-close" onClick={onClose}><i className="ti ti-x" /></button>
        </div>
        <div className="modal-body">
          {error && <div className="alert alert-error mb-16"><i className="ti ti-alert-circle" /><div>{error}</div></div>}
          <div className="form-row cols-2">
            <div className="field-group">
              <label className="field-label">Full Name *</label>
              <input className="field-input" placeholder="e.g. Anjali Sharma" value={form.name} onChange={e => set("name", e.target.value)} />
            </div>
            <div className="field-group">
              <label className="field-label">Email Address *</label>
              <input className="field-input" type="email" placeholder="anjali@gmail.com" value={form.email} onChange={e => set("email", e.target.value)} />
            </div>
          </div>
          <div className="form-row cols-2">
            <div className="field-group">
              <label className="field-label">Position Applied *</label>
              <input className="field-input" placeholder="e.g. Backend Engineer" value={form.position_applied} onChange={e => set("position_applied", e.target.value)} />
            </div>
            <div className="field-group">
              <label className="field-label">Phone</label>
              <input className="field-input" placeholder="+91 98765 43210" value={form.phone} onChange={e => set("phone", e.target.value)} />
            </div>
          </div>
          <div className="form-row cols-2">
            <div className="field-group">
              <label className="field-label">Interview Date</label>
              <input className="field-input" type="date" value={form.interview_date} onChange={e => set("interview_date", e.target.value)} />
            </div>
            <div className="field-group">
              <label className="field-label">Interview Mode</label>
              <select className="field-input field-select" value={form.interview_mode} onChange={e => set("interview_mode", e.target.value)}>
                <option value="in_person">In-Person</option>
                <option value="video_call">Video Call</option>
                <option value="phone">Phone</option>
              </select>
            </div>
          </div>
          <div className="field-group">
            <label className="field-label">Notes</label>
            <textarea className="field-input" rows={3} placeholder="Any notes about this candidate..." value={form.notes} onChange={e => set("notes", e.target.value)} />
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-filled" onClick={handleSave} disabled={saving}>
            {saving ? <><i className="ti ti-loader-2 spin" /> Saving…</> : <><i className="ti ti-check" /> Add to List</>}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Mark Candidate Modal ─────────────────────────────────────────────────────

interface MarkModalProps {
  candidate: Candidate;
  targetStatus: "selected" | "rejected";
  onClose: () => void;
  onConfirmed: (c: Candidate) => void;
}

function MarkCandidateModal({ candidate, targetStatus, onClose, onConfirmed }: MarkModalProps) {
  const [remarks, setRemarks] = useState("");
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState("");

  async function handleConfirm() {
    setSaving(true);
    setError("");
    try {
      const res = await RECRUITMENT_API.setStatus(candidate.id, { status: targetStatus, remarks });
      onConfirmed(res.data.data);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setError(msg || "Action failed.");
    } finally {
      setSaving(false);
    }
  }

  const isSelect = targetStatus === "selected";

  return (
    <div className="modal-overlay open" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 500 }}>
        <div className="modal-header">
          <div className="modal-title">{isSelect ? "Select" : "Reject"} Candidate — {candidate.name}</div>
          <button className="modal-close" onClick={onClose}><i className="ti ti-x" /></button>
        </div>
        <div className="modal-body">
          {error && <div className="alert alert-error mb-16"><i className="ti ti-alert-circle" /><div>{error}</div></div>}
          <div className={`alert ${isSelect ? "alert-success" : "alert-error"} mb-16`}>
            <i className={`ti ${isSelect ? "ti-check" : "ti-x"}`} />
            <div>
              You are marking <strong>{candidate.name}</strong> as <strong>{targetStatus}</strong>.
              An automatic email will be sent using the <em>Interview {isSelect ? "Selection" : "Rejection"}</em> template.
            </div>
          </div>
          <div className="field-group mb-16">
            <label className="field-label">Interview feedback / remarks</label>
            <textarea className="field-input" rows={3} placeholder="Add interview notes..." value={remarks} onChange={e => setRemarks(e.target.value)} />
          </div>
          <div className="settings-card">
            <div className="settings-card-title flex items-center gap-2"><i className="ti ti-mail" />Email Preview</div>
            <div style={{ fontSize: 12, color: "var(--on-variant)" }}><strong>To:</strong> {candidate.email}</div>
            <div style={{ fontSize: 12, color: "var(--on-variant)" }}>
              <strong>Subject:</strong> {isSelect ? `You've been selected for ${candidate.position_applied}` : `Regarding your application for ${candidate.position_applied}`}
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button
            className={`btn ${isSelect ? "btn-success" : "btn-danger"}`}
            onClick={handleConfirm}
            disabled={saving}
          >
            {saving
              ? <><i className="ti ti-loader-2 spin" /> Sending…</>
              : <><i className={`ti ${isSelect ? "ti-check" : "ti-x"}`} /> Confirm & Send Email</>
            }
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Logs Modal ───────────────────────────────────────────────────────────────

function LogsModal({ candidate, onClose }: { candidate: Candidate; onClose: () => void }) {
  const [logs,    setLogs]    = useState<CandidateLog[]>(candidate.logs || []);
  const [loading, setLoading] = useState(!candidate.logs);

  useEffect(() => {
    if (candidate.logs) return;
    RECRUITMENT_API.detail(candidate.id).then(r => setLogs(r.data.data.logs || [])).finally(() => setLoading(false));
  }, [candidate]);

  return (
    <div className="modal-overlay open" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 480 }}>
        <div className="modal-header">
          <div className="modal-title">Activity Log — {candidate.name}</div>
          <button className="modal-close" onClick={onClose}><i className="ti ti-x" /></button>
        </div>
        <div className="modal-body">
          <div className="flex-row mb-16 pb-4 border-b border-[var(--outline-v)]">
            <Avatar name={candidate.name} size={40} />
            <div>
              <div style={{ fontSize: 15, fontWeight: 600 }}>{candidate.name}</div>
              <div style={{ fontSize: 12, color: "var(--on-variant)" }}>{candidate.position_applied} • {candidate.email}</div>
              <StatusBadge status={candidate.status} />
            </div>
          </div>
          {loading ? (
            <div className="text-center py-6"><i className="ti ti-loader-2 spin text-2xl" /></div>
          ) : logs.length === 0 ? (
            <p className="text-center text-[var(--on-variant)]">No activity yet.</p>
          ) : (
            <div className="timeline">
              {logs.map(l => (
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
          )}
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function InterviewListPage() {
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [stats,      setStats]      = useState<RecruitmentStats | null>(null);
  const [loading,    setLoading]    = useState(true);
  const [error,      setError]      = useState("");

  const [search,       setSearch]       = useState("");
  const [statusFilter, setStatusFilter] = useState<"" | CandidateStatus>("");

  const [showAdd,  setShowAdd]  = useState(false);
  const [markData, setMarkData] = useState<{ candidate: Candidate; targetStatus: "selected" | "rejected" } | null>(null);
  const [logsFor,  setLogsFor]  = useState<Candidate | null>(null);

  const searchRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchAll = useCallback(async (q?: string, s?: string) => {
    setLoading(true);
    setError("");
    try {
      const cRes = await RECRUITMENT_API.list({ search: q || undefined, status: s || undefined });
      const raw  = cRes.data?.data;
      setCandidates(Array.isArray(raw?.results) ? raw.results : []);
    } catch {
      setError("Failed to load candidates.");
      setCandidates([]);
    } finally {
      setLoading(false);
    }
    // Stats are non-blocking — failure doesn't break the page
    try {
      const sRes = await RECRUITMENT_API.stats();
      setStats(sRes.data?.data ?? null);
    } catch {
      // silently ignore — stats are cosmetic
    }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  function handleSearch(val: string) {
    setSearch(val);
    if (searchRef.current) clearTimeout(searchRef.current);
    searchRef.current = setTimeout(() => fetchAll(val, statusFilter), 350);
  }

  function handleStatusFilter(val: "" | CandidateStatus) {
    setStatusFilter(val);
    fetchAll(search, val);
  }

  function onCandidateAdded(c: Candidate) {
    setCandidates(prev => [c, ...prev]);
    setStats(prev => prev ? { ...prev, total: prev.total + 1, pending: prev.pending + 1 } : prev);
    setShowAdd(false);
  }

  function onStatusChanged(updated: Candidate) {
    setCandidates(prev => prev.map(c => c.id === updated.id ? updated : c));
    setMarkData(null);
    fetchAll(search, statusFilter); // refresh stats
  }

  const statCards = [
    { label: "Total",    value: stats?.total    ?? "—", icon: "ti-users",       iconCls: "si-primary" },
    { label: "Pending",  value: stats?.pending  ?? "—", icon: "ti-clock",       iconCls: "si-warn" },
    { label: "Selected", value: stats?.selected ?? "—", icon: "ti-user-check",  iconCls: "si-success" },
    { label: "Rejected", value: stats?.rejected ?? "—", icon: "ti-user-x",      iconCls: "si-error" },
  ];

  return (
    <>
      {/* Header */}
      <div className="page-header">
        <div>
          <div className="page-title">Interview List</div>
          <div className="page-sub">Manage all interview candidates and their status</div>
        </div>
        <div className="page-actions">
          <button className="btn btn-filled" onClick={() => setShowAdd(true)}>
            <i className="ti ti-plus" /> Add Candidate
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        {statCards.map(s => (
          <div key={s.label} className="stat-card">
            <div className={`stat-icon ${s.iconCls}`}><i className={`ti ${s.icon}`} /></div>
            <div className="stat-label">{s.label}</div>
            <div className="stat-value">{s.value}</div>
          </div>
        ))}
      </div>

      {/* Info banner */}
      <div className="alert alert-info" style={{ marginBottom: 16 }}>
        <i className="ti ti-info-circle" />
        <div>Mark candidates as Selected or Rejected. Selected candidates will receive a login email automatically.</div>
      </div>

      {/* Table card */}
      <div className="card">
        <div className="card-header">
          <span className="card-title"><i className="ti ti-users" /> All Candidates ({candidates.length})</span>
          <div className="filter-bar" style={{ margin: 0 }}>
            <div className="search-bar">
              <i className="ti ti-search" />
              <input placeholder="Search candidate…" value={search} onChange={e => handleSearch(e.target.value)} />
            </div>
            <select
              className="field-input field-select"
              style={{ width: 140 }}
              value={statusFilter}
              onChange={e => handleStatusFilter(e.target.value as "" | CandidateStatus)}
            >
              <option value="">All Status</option>
              <option value="pending">Pending</option>
              <option value="selected">Selected</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>
        </div>

        {error && <div className="alert alert-error" style={{ margin: "0 20px 16px" }}><i className="ti ti-alert-circle" /><div>{error}</div></div>}

        <div className="table-wrap">
          {loading ? (
            <div className="text-center py-10"><i className="ti ti-loader-2 spin text-3xl" /></div>
          ) : !Array.isArray(candidates) || candidates.length === 0 ? (
            <div className="empty-state"><i className="ti ti-users" /><h3>No candidates found</h3><p>Add a candidate or adjust your filters.</p></div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Position</th>
                  <th>Interview Date</th>
                  <th>Mode</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {candidates.map(c => (
                  <tr key={c.id}>
                    <td>
                      <div className="flex items-center gap-3">
                        <Avatar name={c.name} size={32} />
                        <div>
                          <strong>{c.name}</strong>
                          <div className="text-xs text-[var(--on-variant)]">{c.email}</div>
                        </div>
                      </div>
                    </td>
                    <td>{c.position_applied}</td>
                    <td>{fmtDate(c.interview_date)}</td>
                    <td><span className="text-xs">{MODE_LABELS[c.interview_mode]}</span></td>
                    <td><StatusBadge status={c.status} /></td>
                    <td>
                      <div className="flex items-center gap-2">
                        <button className="btn btn-ghost btn-sm" onClick={() => setLogsFor(c)}>
                          <i className="ti ti-history" /> Logs
                        </button>
                        {c.status === "pending" && (
                          <>
                            <button
                              className="btn btn-success btn-sm"
                              onClick={() => setMarkData({ candidate: c, targetStatus: "selected" })}
                              title="Mark Selected"
                            >
                              <i className="ti ti-check" />
                            </button>
                            <button
                              className="btn btn-danger btn-sm"
                              onClick={() => setMarkData({ candidate: c, targetStatus: "rejected" })}
                              title="Mark Rejected"
                            >
                              <i className="ti ti-x" />
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Modals */}
      {showAdd && <AddCandidateModal onClose={() => setShowAdd(false)} onSaved={onCandidateAdded} />}
      {markData && (
        <MarkCandidateModal
          candidate={markData.candidate}
          targetStatus={markData.targetStatus}
          onClose={() => setMarkData(null)}
          onConfirmed={onStatusChanged}
        />
      )}
      {logsFor && <LogsModal candidate={logsFor} onClose={() => setLogsFor(null)} />}
    </>
  );
}
