"use client";

import { useState } from "react";
import RejectModal from "./RejectModal";

// ─── Types ────────────────────────────────────────────────────────────────────

type ReqStatus = "pending" | "approved" | "rejected";

interface LeaveBalance {
  type:      string;
  icon:      string;
  iconClass: string;
  barColor:  string;
  used:      number;
  total:     number;
}

interface LeaveRequest {
  id:             number;
  employee:       string;
  branch:         string;
  type:           string;
  from:           string;
  to:             string;
  days:           number;
  status:         ReqStatus;
  reject_reason?: string;
}

interface Props {
  onApply:          () => void;
  selectedBranches: string[];
}

// ─── Static data ──────────────────────────────────────────────────────────────

const BALANCES: LeaveBalance[] = [
  { type: "Casual Leave", icon: "ti-circle-check", iconClass: "si-success", barColor: "var(--success)", used: 4, total: 12 },
  { type: "Earned Leave", icon: "ti-calendar",     iconClass: "si-primary",  barColor: "var(--primary)", used: 4, total: 18 },
  { type: "Sick Leave",   icon: "ti-stethoscope",  iconClass: "si-info",     barColor: "var(--info)",    used: 1, total: 6  },
];

const INIT_REQUESTS: LeaveRequest[] = [
  { id: 1, employee: "Arjun Mehta",  branch: "Head Office", type: "Casual Leave", from: "Jun 25", to: "Jun 26", days: 2, status: "pending"  },
  { id: 2, employee: "Meena Iyer",   branch: "Mumbai",      type: "Earned Leave", from: "Jul 1",  to: "Jul 5",  days: 5, status: "pending"  },
  { id: 3, employee: "Suresh Kumar", branch: "Chennai",     type: "Sick Leave",   from: "Jun 20", to: "Jun 20", days: 1, status: "approved" },
  { id: 4, employee: "Priya Sharma", branch: "Hyderabad",   type: "Casual Leave", from: "Jun 28", to: "Jun 28", days: 1, status: "approved" },
  { id: 5, employee: "Rahul Singh",  branch: "Bengaluru",   type: "Earned Leave", from: "Jul 10", to: "Jul 14", days: 5, status: "pending"  },
];

const STATUS_BADGE: Record<ReqStatus, string> = {
  pending:  "badge badge-warn",
  approved: "badge badge-success",
  rejected: "badge badge-error",
};

// ─── Component ────────────────────────────────────────────────────────────────

export default function LeaveDashboard({ onApply, selectedBranches }: Props) {
  const [requests,     setRequests]     = useState<LeaveRequest[]>(INIT_REQUESTS);
  const [rejectTarget, setRejectTarget] = useState<{ id: number; employee: string; type: string } | null>(null);

  const pendingCount    = requests.filter(r => r.status === "pending").length;
  const visibleRequests = selectedBranches.length === 0
    ? requests
    : requests.filter(r => selectedBranches.includes(r.branch));

  function approve(id: number) {
    setRequests(prev => prev.map(r => r.id === id ? { ...r, status: "approved" } : r));
  }

  function handleReject(reason: string) {
    if (!rejectTarget) return;
    setRequests(prev =>
      prev.map(r => r.id === rejectTarget.id ? { ...r, status: "rejected", reject_reason: reason } : r)
    );
    setRejectTarget(null);
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>

      {/* Leave balance cards */}
      <div className="stats-grid" style={{ marginBottom: 0 }}>
        {BALANCES.map(b => {
          const left = b.total - b.used;
          const pct  = Math.round((b.used / b.total) * 100);
          return (
            <div key={b.type} className="stat-card">
              <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 10 }}>
                <div>
                  <div className="stat-label">{b.type}</div>
                  <div className="stat-value">{left}</div>
                  <div className="stat-sub">of {b.total} days left</div>
                </div>
                <div className={`stat-icon ${b.iconClass}`} style={{ float: "none", margin: 0 }}>
                  <i className={`ti ${b.icon}`} />
                </div>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${pct}%`, background: b.barColor }} />
              </div>
            </div>
          );
        })}

        {/* Pending approval */}
        <div className="stat-card">
          <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 10 }}>
            <div>
              <div className="stat-label">Pending Approval</div>
              <div className="stat-value">{pendingCount}</div>
              <div className="stat-sub">Team requests</div>
            </div>
            <div className="stat-icon si-warn" style={{ float: "none", margin: 0 }}>
              <i className="ti ti-checks" />
            </div>
          </div>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: 0 }} />
          </div>
        </div>
      </div>

      {/* AI Insight */}
      <div className="alert alert-info" style={{ marginBottom: 0 }}>
        <i className="ti ti-sparkles" />
        <span>
          <strong>AI Insight:</strong>{" "}
          Leave utilisation is 15% higher this month compared to last month.{" "}
          2 employees have not taken any leave in 60+ days.
        </span>
      </div>

      {/* Recent Leave Requests */}
      <div className="card">
        <div className="card-header">
          <div className="card-title">
            <i className="ti ti-list-details" />
            Recent Leave Requests
            {selectedBranches.length > 0 && (
              <span style={{ fontSize: 12, fontWeight: 400, color: "var(--on-variant)", marginLeft: 4 }}>
                · {visibleRequests.length} shown
              </span>
            )}
          </div>
          <button className="btn btn-filled btn-sm" onClick={onApply}>
            <i className="ti ti-plus" /> Apply Leave
          </button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Employee</th>
                <th>Branch</th>
                <th>Leave Type</th>
                <th>From</th>
                <th>To</th>
                <th style={{ textAlign: "center" }}>Days</th>
                <th style={{ textAlign: "center" }}>Status</th>
                <th style={{ textAlign: "center" }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {visibleRequests.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: "center", padding: "40px 20px" }}>
                    <i className="ti ti-building" style={{ fontSize: 28, display: "block", marginBottom: 8, color: "var(--outline-v)" }} />
                    <span style={{ color: "var(--on-variant)", fontSize: 13 }}>No requests found for the selected branch.</span>
                  </td>
                </tr>
              ) : visibleRequests.map(r => (
                <tr key={r.id}>
                  <td style={{ fontWeight: 600 }}>{r.employee}</td>
                  <td>
                    <span className="badge badge-neutral">{r.branch}</span>
                  </td>
                  <td>{r.type}</td>
                  <td>{r.from}</td>
                  <td>{r.to}</td>
                  <td style={{ textAlign: "center", fontWeight: 700 }}>{r.days}</td>
                  <td style={{ textAlign: "center" }}>
                    <span className={STATUS_BADGE[r.status]} style={{ textTransform: "capitalize" }}>
                      {r.status}
                    </span>
                    {r.status === "rejected" && r.reject_reason && (
                      <div style={{ marginTop: 4 }}>
                        <span
                          title={r.reject_reason}
                          style={{
                            display: "inline-flex", alignItems: "center", gap: 3,
                            padding: "2px 8px", borderRadius: 4,
                            background: "var(--error-c)", color: "var(--error)",
                            fontSize: 11, maxWidth: 140,
                            overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                          }}
                        >
                          <i className="ti ti-message-x" style={{ fontSize: 10 }} />
                          {r.reject_reason}
                        </span>
                      </div>
                    )}
                  </td>
                  <td style={{ textAlign: "center" }}>
                    {r.status === "pending" ? (
                      <div style={{ display: "flex", gap: 6, justifyContent: "center" }}>
                        <button
                          className="btn btn-sm btn-success"
                          onClick={() => approve(r.id)}
                          title="Approve"
                          style={{ padding: "4px 10px" }}
                        >
                          <i className="ti ti-check" />
                        </button>
                        <button
                          className="btn btn-sm btn-danger"
                          onClick={() => setRejectTarget({ id: r.id, employee: r.employee, type: r.type })}
                          title="Reject"
                          style={{ padding: "4px 10px" }}
                        >
                          <i className="ti ti-x" />
                        </button>
                      </div>
                    ) : (
                      <span style={{ color: "var(--outline-v)" }}>—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {rejectTarget && (
        <RejectModal
          employee={rejectTarget.employee}
          leaveType={rejectTarget.type}
          onCancel={() => setRejectTarget(null)}
          onConfirm={handleReject}
        />
      )}
    </div>
  );
}
