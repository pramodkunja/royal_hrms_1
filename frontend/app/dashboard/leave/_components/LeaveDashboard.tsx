"use client";

import { useState } from "react";
import { useFetch } from "@/hooks/useFetch";
import { API } from "@/lib/api/endpoints";
import clientApi from "@/lib/clientApi";
import {
  LeaveBalance, LeaveRequest, LeaveStats,
  LEAVE_TYPE_CONFIG, STATUS_BADGE, STATUS_LABEL,
  fmtShortDate,
} from "../_data";
import RejectModal from "./RejectModal";

interface Props {
  onApply:          () => void;
  selectedBranches: string[];
}

const BALANCE_DISPLAY = [
  { key: "casual" as const, icon: "ti-circle-check", iconClass: "si-success", barColor: "var(--success)" },
  { key: "earned" as const, icon: "ti-calendar",     iconClass: "si-primary",  barColor: "var(--primary)" },
  { key: "sick"   as const, icon: "ti-stethoscope",  iconClass: "si-info",     barColor: "var(--info)"    },
];

export default function LeaveDashboard({ onApply, selectedBranches }: Props) {
  const [rejectTarget, setRejectTarget] = useState<{ id: string; employee: string; type: string } | null>(null);
  const [actioning,    setActioning]    = useState<string | null>(null);

  const currentYear = new Date().getFullYear();
  const { data: stats,    refetch: refetchStats }    = useFetch<LeaveStats>(API.leave.stats + `?year=${currentYear}`);
  const { data: requests, refetch: refetchRequests, loading } = useFetch<LeaveRequest[]>(API.leave.requests + "?status=pending");
  const { data: balances } = useFetch<LeaveBalance[]>(API.leave.balance + `?year=${currentYear}`);

  const balanceMap = Object.fromEntries((balances ?? []).map(b => [b.leave_type, b]));

  const visibleRequests = selectedBranches.length === 0
    ? (requests ?? [])
    : (requests ?? []).filter(r => selectedBranches.includes(r.employee_branch));

  const pendingCount = stats?.pending ?? 0;

  async function approve(id: string) {
    setActioning(id);
    try {
      await clientApi.post(API.leave.approve(id), { action: "approve" });
      refetchRequests();
      refetchStats();
    } catch {
      // error handled silently; request stays visible
    } finally {
      setActioning(null);
    }
  }

  async function handleReject(reason: string) {
    if (!rejectTarget) return;
    setActioning(rejectTarget.id);
    try {
      await clientApi.post(API.leave.approve(rejectTarget.id), { action: "reject", remarks: reason });
      refetchRequests();
      refetchStats();
    } catch {
      // error handled silently
    } finally {
      setActioning(null);
      setRejectTarget(null);
    }
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>

      {/* Leave balance cards */}
      <div className="stats-grid" style={{ marginBottom: 0 }}>
        {BALANCE_DISPLAY.map(({ key, icon, iconClass, barColor }) => {
          const b     = balanceMap[key];
          const total = b ? Number(b.total_days)   : 0;
          const used  = b ? Number(b.used_days)    : 0;
          const left  = total - used;
          const pct   = total > 0 ? Math.round((used / total) * 100) : 0;
          const label = LEAVE_TYPE_CONFIG[key].label;
          return (
            <div key={key} className="stat-card">
              <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 10 }}>
                <div>
                  <div className="stat-label">{label}</div>
                  <div className="stat-value">{left}</div>
                  <div className="stat-sub">of {total} days left</div>
                </div>
                <div className={`stat-icon ${iconClass}`} style={{ float: "none", margin: 0 }}>
                  <i className={`ti ${icon}`} />
                </div>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${pct}%`, background: barColor }} />
              </div>
            </div>
          );
        })}

        {/* Pending approval count */}
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
          <div className="progress-bar"><div className="progress-fill" style={{ width: 0 }} /></div>
        </div>
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
          {loading ? (
            <div style={{ padding: "40px 20px", textAlign: "center" }}>
              <i className="ti ti-loader-2" style={{ fontSize: 24, color: "var(--outline-v)" }} />
            </div>
          ) : (
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
                      <span style={{ color: "var(--on-variant)", fontSize: 13 }}>
                        {selectedBranches.length > 0 ? "No requests found for the selected branch." : "No pending leave requests."}
                      </span>
                    </td>
                  </tr>
                ) : visibleRequests.map(r => (
                  <tr key={r.id}>
                    <td style={{ fontWeight: 600 }}>{r.employee_name}</td>
                    <td><span className="badge badge-neutral">{r.employee_branch || "—"}</span></td>
                    <td>{r.leave_type_display}</td>
                    <td>{fmtShortDate(r.start_date)}</td>
                    <td>{fmtShortDate(r.end_date)}</td>
                    <td style={{ textAlign: "center", fontWeight: 700 }}>{r.total_days}</td>
                    <td style={{ textAlign: "center" }}>
                      <span className={STATUS_BADGE[r.status]} style={{ textTransform: "capitalize" }}>
                        {STATUS_LABEL[r.status]}
                      </span>
                    </td>
                    <td style={{ textAlign: "center" }}>
                      {r.status === "pending" || r.status === "l2_pending" ? (
                        <div style={{ display: "flex", gap: 6, justifyContent: "center" }}>
                          <button
                            className="btn btn-sm btn-success"
                            onClick={() => approve(r.id)}
                            disabled={actioning === r.id}
                            title="Approve"
                            style={{ padding: "4px 10px" }}
                          >
                            {actioning === r.id ? <i className="ti ti-loader-2" /> : <i className="ti ti-check" />}
                          </button>
                          <button
                            className="btn btn-sm btn-danger"
                            onClick={() => setRejectTarget({ id: r.id, employee: r.employee_name, type: r.leave_type_display })}
                            disabled={actioning === r.id}
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
          )}
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
