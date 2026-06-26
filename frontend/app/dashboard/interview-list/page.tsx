"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { API } from "@/lib/api/endpoints";
import clientApi from "@/lib/clientApi";
import {
  Branch,
  Candidate,
  CandidateStatus,
  RECRUITMENT_API,
  RecruitmentStats,
  fmtDate,
  initials,
  MODE_LABELS,
} from "./_data";
import { AddCandidateModal }  from "./AddCandidateModal";
import { MarkCandidateModal } from "./MarkCandidateModal";
import { LogsModal }          from "./LogsModal";

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
    <div className="user-avatar" style={{ width: size, height: size, fontSize: size * 0.38, flexShrink: 0 }}>
      {initials(name)}
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function InterviewListPage() {
  const [candidates,    setCandidates]    = useState<Candidate[]>([]);
  const [stats,         setStats]         = useState<RecruitmentStats | null>(null);
  const [loading,       setLoading]       = useState(true);
  const [error,         setError]         = useState("");

  const [search,        setSearch]        = useState("");
  const [statusFilter,  setStatusFilter]  = useState<"" | CandidateStatus>("");
  const [branchFilter,  setBranchFilter]  = useState<number | "">("");
  const [branches,      setBranches]      = useState<Branch[]>([]);

  const [showAdd,  setShowAdd]  = useState(false);
  const [markData, setMarkData] = useState<{ candidate: Candidate; targetStatus: "selected" | "rejected" } | null>(null);
  const [logsFor,  setLogsFor]  = useState<Candidate | null>(null);

  const searchRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Fetch active branches once for the dropdown
  useEffect(() => {
    clientApi
      .get<{ data: { results: Branch[] } }>(API.branches.list, {
        params: { status: "active", page_size: 100 },
      })
      .then(r => setBranches(r.data?.data?.results ?? []))
      .catch(() => {});
  }, []);

  const fetchAll = useCallback(async (
    q?: string,
    s?: string,
    b?: number | "",
  ) => {
    setLoading(true);
    setError("");
    try {
      const cRes = await RECRUITMENT_API.list({
        search: q   || undefined,
        status: s   || undefined,
        branch: b   || undefined,
      });
      const raw = cRes.data?.data;
      setCandidates(Array.isArray(raw?.results) ? raw.results : []);
    } catch {
      setError("Failed to load candidates.");
      setCandidates([]);
    } finally {
      setLoading(false);
    }
    try {
      const sRes = await RECRUITMENT_API.stats();
      setStats(sRes.data?.data ?? null);
    } catch {
      // stats are cosmetic — ignore failure
    }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  function handleSearch(val: string) {
    setSearch(val);
    if (searchRef.current) clearTimeout(searchRef.current);
    searchRef.current = setTimeout(() => fetchAll(val, statusFilter, branchFilter), 350);
  }

  function handleStatusFilter(val: "" | CandidateStatus) {
    setStatusFilter(val);
    fetchAll(search, val, branchFilter);
  }

  function handleBranchFilter(val: number | "") {
    setBranchFilter(val);
    fetchAll(search, statusFilter, val);
  }

  function onCandidateAdded(c: Candidate) {
    setCandidates(prev => [c, ...prev]);
    setStats(prev => prev ? { ...prev, total: prev.total + 1, pending: prev.pending + 1 } : prev);
    setShowAdd(false);
  }

  function onStatusChanged(updated: Candidate) {
    setCandidates(prev => prev.map(c => c.id === updated.id ? updated : c));
    setMarkData(null);
    fetchAll(search, statusFilter, branchFilter);
  }

  const activeBranch = branches.find(b => b.id === branchFilter);

  const statCards = [
    { label: "Total",    value: stats?.total    ?? "—", icon: "ti-users",      iconCls: "si-primary" },
    { label: "Pending",  value: stats?.pending  ?? "—", icon: "ti-clock",      iconCls: "si-warn" },
    { label: "Selected", value: stats?.selected ?? "—", icon: "ti-user-check", iconCls: "si-success" },
    { label: "Rejected", value: stats?.rejected ?? "—", icon: "ti-user-x",     iconCls: "si-error" },
  ];

  return (
    <>
      {/* Header */}
      <div className="page-header">
        <div>
          <div className="page-title">Interview List</div>
          <div className="page-sub">
            {activeBranch
              ? <>Showing candidates for <strong>{activeBranch.branch_name}</strong></>
              : "Manage all interview candidates and their status"}
          </div>
        </div>
        <div className="page-actions" style={{ gap: 10 }}>
          {/* Branch filter dropdown */}
          <div style={{ position: "relative" }}>
            <select
              className="field-input field-select"
              style={{ minWidth: 180, paddingLeft: 32 }}
              value={branchFilter}
              onChange={e => handleBranchFilter(e.target.value ? Number(e.target.value) : "")}
            >
              <option value="">All Branches</option>
              {branches.map(b => (
                <option key={b.id} value={b.id}>
                  {b.branch_name} ({b.branch_code})
                </option>
              ))}
            </select>
            <i
              className="ti ti-building"
              style={{
                position: "absolute", left: 10, top: "50%",
                transform: "translateY(-50%)", color: "var(--on-variant)",
                pointerEvents: "none",
              }}
            />
          </div>

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

      {/* Table */}
      <div className="card">
        <div className="card-header">
          <span className="card-title">
            <i className="ti ti-users" />
            {activeBranch ? `${activeBranch.branch_name} Candidates` : "All Candidates"} ({candidates.length})
          </span>
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

        {error && (
          <div className="alert alert-error" style={{ margin: "0 20px 16px" }}>
            <i className="ti ti-alert-circle" /><div>{error}</div>
          </div>
        )}

        <div className="table-wrap">
          {loading ? (
            <div className="text-center py-10"><i className="ti ti-loader-2 spin text-3xl" /></div>
          ) : !Array.isArray(candidates) || candidates.length === 0 ? (
            <div className="empty-state">
              <i className="ti ti-users" />
              <h3>{activeBranch ? `No candidates in ${activeBranch.branch_name}` : "No candidates found"}</h3>
              <p>{activeBranch ? "Add a candidate to this branch to get started." : "Add a candidate or adjust your filters."}</p>
            </div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Candidate</th><th>Position</th><th>Branch</th>
                  <th>Interview Date</th><th>Mode</th><th>Status</th><th>Actions</th>
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
                    <td>
                      {c.branch_name
                        ? <span className="badge badge-neutral" style={{ fontSize: 11 }}>{c.branch_name}</span>
                        : <span className="text-xs text-[var(--on-variant)]">—</span>}
                    </td>
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
