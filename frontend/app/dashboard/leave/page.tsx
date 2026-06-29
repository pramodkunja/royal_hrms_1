"use client";

import { useState } from "react";
import LeaveDashboard from "./_components/LeaveDashboard";
import LeaveApprovals from "./_components/LeaveApprovals";
import ApplyLeaveForm from "./_components/ApplyLeaveForm";
import TeamCalendar   from "./_components/TeamCalendar";
import LeaveAnalytics from "./_components/LeaveAnalytics";
import BranchDropdown from "./_components/BranchDropdown";

type TabId = "dashboard" | "apply" | "approvals" | "calendar" | "analytics";

const TABS: { id: TabId; label: string }[] = [
  { id: "dashboard",  label: "Dashboard"     },
  { id: "apply",      label: "Apply Leave"   },
  { id: "approvals",  label: "Approvals"     },
  { id: "calendar",   label: "Team Calendar" },
  { id: "analytics",  label: "Analytics"     },
];

export default function LeavePage() {
  const [active,           setActive]           = useState<TabId>("dashboard");
  const [selectedBranches, setSelectedBranches] = useState<string[]>([]);

  return (
    <div>
      {/* Page header — title left, branch filter right */}
      <div className="page-header">
        <div>
          <div className="page-title">Leave Management</div>
          <div className="page-sub">Apply, approve and track all leave requests</div>
        </div>
        <BranchDropdown selected={selectedBranches} onChange={setSelectedBranches} />
      </div>

      {/* Tab bar */}
      <div className="tabs">
        {TABS.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActive(tab.id)}
            className={`tab${active === tab.id ? " active" : ""}`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div>
        {active === "dashboard"  && <LeaveDashboard selectedBranches={selectedBranches} onApply={() => setActive("apply")} />}
        {active === "apply"      && <ApplyLeaveForm  onCancel={() => setActive("dashboard")} />}
        {active === "approvals"  && <LeaveApprovals  />}
        {active === "calendar"   && <TeamCalendar    />}
        {active === "analytics"  && <LeaveAnalytics  />}
      </div>
    </div>
  );
}
