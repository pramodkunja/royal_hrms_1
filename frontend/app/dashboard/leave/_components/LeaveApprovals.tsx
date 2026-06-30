"use client";

import { useState } from "react";

type Status = "pending" | "approved" | "rejected";

interface ApprovalRequest {
  id:      number;
  employee: string;
  dept:    string;
  type:    string;
  from:    string;
  to:      string;
  days:    number;
  applied: string;
  status:  Status;
}

const SEED: ApprovalRequest[] = [
  { id: 1, employee: "Arjun Mehta",  dept: "Engineering", type: "Casual Leave", from: "Jun 25", to: "Jun 26", days: 2, applied: "Jun 19", status: "pending"  },
  { id: 2, employee: "Meena Iyer",   dept: "HR",          type: "Earned Leave", from: "Jul 1",  to: "Jul 5",  days: 5, applied: "Jun 18", status: "pending"  },
  { id: 3, employee: "Rahul Singh",  dept: "Engineering", type: "Earned Leave", from: "Jul 10", to: "Jul 14", days: 5, applied: "Jun 20", status: "pending"  },
  { id: 4, employee: "Suresh Kumar", dept: "Sales",       type: "Sick Leave",   from: "Jun 20", to: "Jun 20", days: 1, applied: "Jun 15", status: "approved" },
  { id: 5, employee: "Priya Sharma", dept: "Finance",     type: "Casual Leave", from: "Jun 28", to: "Jun 28", days: 1, applied: "Jun 22", status: "approved" },
  { id: 6, employee: "Kavya Nair",   dept: "Marketing",   type: "Casual Leave", from: "Jun 30", to: "Jun 30", days: 1, applied: "Jun 28", status: "rejected" },
];

const STATUS_BADGE: Record<Status, string> = {
  pending:  "bg-amber-100 text-amber-700",
  approved: "bg-green-100 text-green-700",
  rejected: "bg-red-100   text-red-600",
};

type Tab = "pending" | "history";

export default function LeaveApprovals() {
  const [requests, setRequests] = useState<ApprovalRequest[]>(SEED);
  const [tab,      setTab]      = useState<Tab>("pending");

  const pending = requests.filter(r => r.status === "pending");
  const history = requests.filter(r => r.status !== "pending");
  const rows    = tab === "pending" ? pending : history;

  function approve(id: number) {
    setRequests(prev => prev.map(r => r.id === id ? { ...r, status: "approved" } : r));
  }

  function reject(id: number) {
    setRequests(prev => prev.map(r => r.id === id ? { ...r, status: "rejected" } : r));
  }

  return (
    <div className="flex flex-col gap-5">

      {/* Sub-tabs */}
      <div className="flex gap-2">
        <button
          onClick={() => setTab("pending")}
          className={[
            "px-4 py-1.5 rounded-full text-sm font-medium border transition-all",
            tab === "pending"
              ? "bg-blue-700 text-white border-blue-700"
              : "bg-white text-gray-500 border-gray-200 hover:border-blue-600 hover:text-blue-600",
          ].join(" ")}
        >
          Pending
          {pending.length > 0 && (
            <span className={[
              "ml-2 inline-flex items-center justify-center w-5 h-5 rounded-full text-xs font-bold",
              tab === "pending" ? "bg-white text-blue-700" : "bg-amber-100 text-amber-700",
            ].join(" ")}>
              {pending.length}
            </span>
          )}
        </button>
        <button
          onClick={() => setTab("history")}
          className={[
            "px-4 py-1.5 rounded-full text-sm font-medium border transition-all",
            tab === "history"
              ? "bg-blue-700 text-white border-blue-700"
              : "bg-white text-gray-500 border-gray-200 hover:border-blue-600 hover:text-blue-600",
          ].join(" ")}
        >
          History
        </button>
      </div>

      {/* Table card */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">

        {/* Card header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-green-100 flex items-center justify-center flex-shrink-0">
            <i className="ti ti-checks text-sm text-green-600" />
          </div>
          <span className="text-sm font-bold text-gray-800">
            {tab === "pending" ? "Pending Approvals" : "Approval History"}
          </span>
          {tab === "pending" && pending.length > 0 && (
            <span className="ml-auto text-xs font-medium text-amber-600 bg-amber-50 border border-amber-100 rounded-full px-2.5 py-0.5">
              {pending.length} awaiting action
            </span>
          )}
        </div>

        {rows.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
            <i className="ti ti-circle-check text-4xl text-green-400" />
            <p className="text-sm font-medium">
              {tab === "pending" ? "All caught up — no pending requests." : "No history to show."}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-100">
                  <th className="px-5 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">Employee</th>
                  <th className="px-5 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">Type</th>
                  <th className="px-5 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">Duration</th>
                  <th className="px-5 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">Applied On</th>
                  <th className="px-5 py-3 text-center text-xs font-bold text-gray-400 uppercase tracking-wider">
                    {tab === "pending" ? "Action" : "Status"}
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, idx) => (
                  <tr
                    key={r.id}
                    className={[
                      "transition-colors hover:bg-gray-50",
                      idx < rows.length - 1 ? "border-b border-gray-100" : "",
                    ].join(" ")}
                  >
                    <td className="px-5 py-4">
                      <div className="font-semibold text-gray-800 text-sm">{r.employee}</div>
                      <div className="text-xs text-gray-400 mt-0.5">{r.dept}</div>
                    </td>

                    <td className="px-5 py-4 text-sm text-gray-700">{r.type}</td>

                    <td className="px-5 py-4">
                      <span className="text-sm text-gray-700">{r.from} – {r.to}</span>
                      <span className="ml-2 text-xs font-semibold text-blue-700 bg-blue-50 rounded px-1.5 py-0.5">
                        {r.days}d
                      </span>
                    </td>

                    <td className="px-5 py-4 text-sm text-gray-500">{r.applied}</td>

                    <td className="px-5 py-4 text-center">
                      {tab === "pending" ? (
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => approve(r.id)}
                            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-green-600 hover:bg-green-700 text-white text-xs font-semibold transition-colors"
                          >
                            <i className="ti ti-check" /> Approve
                          </button>
                          <button
                            onClick={() => reject(r.id)}
                            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-red-600 hover:bg-red-700 text-white text-xs font-semibold transition-colors"
                          >
                            <i className="ti ti-x" /> Reject
                          </button>
                        </div>
                      ) : (
                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold capitalize ${STATUS_BADGE[r.status]}`}>
                          {r.status}
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
