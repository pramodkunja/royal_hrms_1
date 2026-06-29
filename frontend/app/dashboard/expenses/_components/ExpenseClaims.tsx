"use client";

import { useState } from "react";
import ExpenseFormModal from "./ExpenseFormModal";
import ExpenseConfirmModal from "./ExpenseConfirmModal";

type ExpenseStatus   = "approved" | "pending" | "rejected";
type ExpenseCategory = "Travel" | "Meals" | "Equipment" | "Other";
type FilterTab       = "All" | ExpenseCategory;

interface Expense {
  id:         number;
  title:      string;
  employee:   string;
  branch:     string;
  date:       string;
  hasReceipt: boolean;
  category:   ExpenseCategory;
  amount:     number;
  status:     ExpenseStatus;
}

const BRANCHES = ["Mumbai", "Bangalore", "Delhi", "Chennai", "Hyderabad"];

const INITIAL_EXPENSES: Expense[] = [
  { id: 1, title: "Client visit to Mumbai",   employee: "Arjun Mehta",   branch: "Mumbai",    date: "Jun 18, 2025", hasReceipt: true,  category: "Travel",    amount: 18500, status: "approved" },
  { id: 2, title: "Team dinner — quarterly",  employee: "Arjun Mehta",   branch: "Mumbai",    date: "Jun 15, 2025", hasReceipt: true,  category: "Meals",     amount: 6240,  status: "approved" },
  { id: 3, title: "External monitor for WFH", employee: "Priya Sharma",  branch: "Bangalore", date: "Jun 17, 2025", hasReceipt: true,  category: "Equipment", amount: 14999, status: "pending"  },
  { id: 4, title: "Laptop bag for travel",    employee: "Suresh Kumar",  branch: "Delhi",     date: "Jun 20, 2025", hasReceipt: true,  category: "Equipment", amount: 1850,  status: "pending"  },
  { id: 5, title: "Conference registration",  employee: "Meena Iyer",    branch: "Chennai",   date: "Jun 10, 2025", hasReceipt: true,  category: "Travel",    amount: 22300, status: "approved" },
  { id: 6, title: "Team lunch — offsite",     employee: "Kavitha Rajan", branch: "Hyderabad", date: "Jun 22, 2025", hasReceipt: false, category: "Meals",     amount: 3511,  status: "rejected" },
];

const FILTER_TABS: { value: FilterTab; label: string; icon: string }[] = [
  { value: "All",       label: "All Claims", icon: "ti-list"                   },
  { value: "Travel",    label: "Travel",     icon: "ti-plane-departure"        },
  { value: "Meals",     label: "Meals",      icon: "ti-tools-kitchen-2"        },
  { value: "Equipment", label: "Equipment",  icon: "ti-device-desktop"         },
  { value: "Other",     label: "Other",      icon: "ti-dots-circle-horizontal" },
];

const CATEGORY_ICON: Record<ExpenseCategory, string> = {
  Travel:    "ti-plane-departure",
  Meals:     "ti-tools-kitchen-2",
  Equipment: "ti-device-desktop",
  Other:     "ti-dots-circle-horizontal",
};

const CATEGORY_STYLE: Record<ExpenseCategory, { bg: string; color: string }> = {
  Travel:    { bg: "rgba(30,78,140,0.10)",   color: "var(--primary)"    },
  Meals:     { bg: "rgba(181,101,29,0.10)",  color: "var(--warn)"       },
  Equipment: { bg: "rgba(14,124,134,0.10)",  color: "var(--info)"       },
  Other:     { bg: "var(--bg-high)",         color: "var(--on-variant)" },
};

const STATUS_BADGE: Record<ExpenseStatus, { cls: string; label: string }> = {
  approved: { cls: "badge-success", label: "approved" },
  pending:  { cls: "badge-warn",    label: "pending"  },
  rejected: { cls: "badge-error",   label: "rejected" },
};

function formatTotal(amount: number): string {
  if (amount >= 100_000) return `₹${(amount / 100_000).toFixed(1)}L`;
  if (amount >= 1_000)   return `₹${(amount / 1_000).toFixed(1)}K`;
  return `₹${amount.toLocaleString("en-IN")}`;
}

export default function ExpenseClaims() {
  const [expenses,       setExpenses]       = useState<Expense[]>(INITIAL_EXPENSES);
  const [activeFilter,   setActiveFilter]   = useState<FilterTab>("All");
  const [activeBranch,   setActiveBranch]   = useState("all");
  const [showNewExpense, setShowNewExpense] = useState(false);
  const [approveTarget,  setApproveTarget]  = useState<Expense | null>(null);
  const [rejectTarget,   setRejectTarget]   = useState<Expense | null>(null);

  const branchFiltered = activeBranch === "all" ? expenses : expenses.filter(e => e.branch === activeBranch);
  const filtered       = activeFilter === "All" ? branchFiltered : branchFiltered.filter(e => e.category === activeFilter);
  const pendingList    = expenses.filter(e => e.status === "pending");
  const approvedList   = expenses.filter(e => e.status === "approved");
  const totalAmount    = expenses.reduce((sum, e) => sum + e.amount, 0);

  function handleApprove() {
    if (!approveTarget) return;
    setExpenses(prev => prev.map(e => e.id === approveTarget.id ? { ...e, status: "approved" as const } : e));
    setApproveTarget(null);
  }

  function handleReject() {
    if (!rejectTarget) return;
    setExpenses(prev => prev.map(e => e.id === rejectTarget.id ? { ...e, status: "rejected" as const } : e));
    setRejectTarget(null);
  }

  function handleNewExpenseSubmit(data: { title: string; amount: number; category: ExpenseCategory; date: string; employee: string }) {
    const nextId = Math.max(...expenses.map(e => e.id)) + 1;
    setExpenses(prev => [
      ...prev,
      { id: nextId, hasReceipt: false, status: "pending", branch: activeBranch === "all" ? "Mumbai" : activeBranch, ...data },
    ]);
    setShowNewExpense(false);
  }

  return (
    <>
      {/* Page header */}
      <div className="page-header">
        <div>
          <div className="page-title">Expense Claims</div>
          <div className="page-sub">All employee expenses</div>
        </div>
        <div className="page-actions">
          <select
            className="field-input"
            style={{ minWidth: 148 }}
            value={activeBranch}
            onChange={e => setActiveBranch(e.target.value)}
            suppressHydrationWarning
          >
            <option value="all">All Branches</option>
            {BRANCHES.map(b => (
              <option key={b} value={b}>{b} Branch</option>
            ))}
          </select>
          <button className="btn btn-filled" onClick={() => setShowNewExpense(true)} suppressHydrationWarning>
            <i className="ti ti-plus" /> New Expense
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon si-primary"><i className="ti ti-file-invoice" /></div>
          <div className="stat-label">Total Claims</div>
          <div className="stat-value">{expenses.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon si-warn"><i className="ti ti-clock" /></div>
          <div className="stat-label">Pending</div>
          <div className="stat-value">{pendingList.length}</div>
          <div className="stat-sub">₹{pendingList.reduce((s, e) => s + e.amount, 0).toLocaleString("en-IN")}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon si-success"><i className="ti ti-check" /></div>
          <div className="stat-label">Approved</div>
          <div className="stat-value">{approvedList.length}</div>
          <div className="stat-sub">₹{approvedList.reduce((s, e) => s + e.amount, 0).toLocaleString("en-IN")}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon si-info"><i className="ti ti-cash" /></div>
          <div className="stat-label">Total Amount</div>
          <div className="stat-value">{formatTotal(totalAmount)}</div>
        </div>
      </div>

      {/* Category filter tabs — scrollable on mobile */}
      <div className="filter-bar filter-scroll mb-16">
        {FILTER_TABS.map(tab => (
          <button
            key={tab.value}
            className={`btn ${activeFilter === tab.value ? "btn-filled" : "btn-ghost"}`}
            onClick={() => setActiveFilter(tab.value)}
            suppressHydrationWarning
          >
            <i className={`ti ${tab.icon}`} /> {tab.label}
          </button>
        ))}
      </div>

      {/* Expense list */}
      <div className="card">
        {filtered.length === 0 ? (
          <div className="empty-state">
            <i className="ti ti-wallet" />
            <h3>No expenses found</h3>
            <p>No claims match the selected filters.</p>
          </div>
        ) : (
          filtered.map((expense, idx) => {
            const catStyle  = CATEGORY_STYLE[expense.category];
            const catIcon   = CATEGORY_ICON[expense.category];
            const { cls, label } = STATUS_BADGE[expense.status];
            const isPending = expense.status === "pending";

            return (
              <div
                key={expense.id}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 14,
                  padding: "16px 20px",
                  borderBottom: idx < filtered.length - 1 ? "1px solid var(--outline-v)" : "none",
                  flexWrap: "wrap",
                }}
              >
                {/* Category icon */}
                <div style={{
                  width: 44, height: 44, borderRadius: 10,
                  background: catStyle.bg, color: catStyle.color,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: 20, flexShrink: 0,
                }}>
                  <i className={`ti ${catIcon}`} />
                </div>

                {/* Details */}
                <div style={{ flex: 1, minWidth: 160 }}>
                  <div style={{ fontWeight: 600, fontSize: 14, color: "var(--on-bg)", marginBottom: 5 }}>
                    {expense.title}
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: 10, flexWrap: "wrap", fontSize: 12, color: "var(--on-variant)" }}>
                    <span style={{ display: "flex", alignItems: "center", gap: 3 }}>
                      <i className="ti ti-user" style={{ fontSize: 13 }} /> {expense.employee}
                    </span>
                    <span style={{ display: "flex", alignItems: "center", gap: 3 }}>
                      <i className="ti ti-building" style={{ fontSize: 13 }} /> {expense.branch}
                    </span>
                    <span style={{ display: "flex", alignItems: "center", gap: 3 }}>
                      <i className="ti ti-calendar" style={{ fontSize: 13 }} /> {expense.date}
                    </span>
                    {expense.hasReceipt && (
                      <span style={{ display: "flex", alignItems: "center", gap: 3 }}>
                        <i className="ti ti-paperclip" style={{ fontSize: 13 }} /> Receipt
                      </span>
                    )}
                    <span className="badge badge-neutral" style={{ fontSize: 10 }}>
                      {expense.category}
                    </span>
                  </div>
                </div>

                {/* Amount + status + action buttons */}
                <div style={{ display: "flex", alignItems: "center", gap: 10, flexShrink: 0, flexWrap: "wrap" }}>
                  <span style={{ fontSize: 16, fontWeight: 700, color: "var(--on-bg)" }}>
                    ₹{expense.amount.toLocaleString("en-IN")}
                  </span>
                  <span className={`badge ${cls}`}>{label}</span>

                  {isPending && (
                    <>
                      <button
                        title="Approve expense"
                        onClick={() => setApproveTarget(expense)}
                        style={{
                          width: 36, height: 36, borderRadius: 8,
                          background: "var(--success)", color: "#fff",
                          border: "none", cursor: "pointer",
                          display: "flex", alignItems: "center", justifyContent: "center",
                          fontSize: 16,
                        }}
                        suppressHydrationWarning
                      >
                        <i className="ti ti-check" />
                      </button>
                      <button
                        title="Reject expense"
                        onClick={() => setRejectTarget(expense)}
                        style={{
                          width: 36, height: 36, borderRadius: 8,
                          background: "var(--error)", color: "#fff",
                          border: "none", cursor: "pointer",
                          display: "flex", alignItems: "center", justifyContent: "center",
                          fontSize: 16,
                        }}
                        suppressHydrationWarning
                      >
                        <i className="ti ti-x" />
                      </button>
                    </>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* New Expense modal */}
      {showNewExpense && (
        <ExpenseFormModal
          onClose={() => setShowNewExpense(false)}
          onSubmit={handleNewExpenseSubmit}
        />
      )}

      {/* Approve confirmation */}
      {approveTarget && (
        <ExpenseConfirmModal
          type="approve"
          expense={approveTarget}
          onConfirm={handleApprove}
          onCancel={() => setApproveTarget(null)}
        />
      )}

      {/* Reject confirmation */}
      {rejectTarget && (
        <ExpenseConfirmModal
          type="reject"
          expense={rejectTarget}
          onConfirm={handleReject}
          onCancel={() => setRejectTarget(null)}
        />
      )}
    </>
  );
}
