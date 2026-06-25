"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  getEmployees,
  fullName,
  initials,
  formatDate,
  deptTint,
  avatarColor,
  TINTS,
  DEPARTMENT_OPTIONS,
  type Employee,
  type EmployeeStatus,
} from "./_data";
import Avatar from "./_components/Avatar";
import StatusBadge from "./_components/StatusBadge";
import AddEmployeeWizard from "./_components/AddEmployeeWizard";

const STATUS_FILTERS: { value: "all" | EmployeeStatus; label: string }[] = [
  { value: "all", label: "All Status" },
  { value: "active", label: "Active" },
  { value: "onboarding", label: "Onboarding" },
  { value: "inactive", label: "Inactive" },
];

export default function EmployeesPage() {
  const router = useRouter();
  const [employees, setEmployees] = useState<Employee[]>(() => [...getEmployees()]);
  const [search, setSearch] = useState("");
  const [dept, setDept] = useState("all");
  const [status, setStatus] = useState<"all" | EmployeeStatus>("all");
  const [showWizard, setShowWizard] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return employees.filter(e => {
      const matchesQ =
        !q ||
        fullName(e).toLowerCase().includes(q) ||
        e.email.toLowerCase().includes(q) ||
        e.code.toLowerCase().includes(q) ||
        e.designation.toLowerCase().includes(q);
      const matchesDept = dept === "all" || e.department === dept;
      const matchesStatus = status === "all" || e.status === status;
      return matchesQ && matchesDept && matchesStatus;
    });
  }, [employees, search, dept, status]);

  const stats = useMemo(() => {
    const active = employees.filter(e => e.status === "active").length;
    const onboarding = employees.filter(e => e.status === "onboarding").length;
    const depts = new Set(employees.map(e => e.department)).size;
    return [
      { label: "Total Employees", value: employees.length, icon: "ti-users",        tint: "primary"   as const },
      { label: "Active",          value: active,           icon: "ti-user-check",   tint: "success"   as const },
      { label: "Onboarding",      value: onboarding,       icon: "ti-user-plus",    tint: "warn"      as const },
      { label: "Departments",     value: depts,            icon: "ti-building",     tint: "info"      as const },
    ];
  }, [employees]);

  function open(id: string) {
    router.push(`/dashboard/employees/${id}`);
  }

  return (
    <div>
      {/* ── Header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3 mb-6">
        <div>
          <h1 className="text-[22px] font-bold text-[var(--on-bg)] tracking-tight mb-1">Employees</h1>
          <p className="text-[13px] text-[var(--on-variant)]">All active and onboarding employees</p>
        </div>
        <button
          onClick={() => setShowWizard(true)}
          suppressHydrationWarning
          className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-[13.5px] font-semibold text-white transition-all shadow-md hover:shadow-lg active:scale-[0.98]"
          style={{ background: "#1e3a5f" }}
        >
          <i className="ti ti-plus text-[15px]" />
          Add Employee
        </button>
      </div>

      {/* ── Stats Row ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-6">
        {stats.map(st => (
          <div
            key={st.label}
            className="bg-white rounded-xl border border-[var(--outline-v)] p-4 sm:p-5 flex items-center justify-between hover:shadow-md transition-shadow"
          >
            <div>
              <div className="text-[11px] sm:text-[12px] font-medium text-[var(--on-variant)] mb-1">{st.label}</div>
              <div className="text-[22px] sm:text-[28px] font-bold text-[var(--on-bg)] leading-none tracking-tight">{st.value}</div>
            </div>
            <div className={`w-9 h-9 sm:w-[42px] sm:h-[42px] rounded-[10px] flex items-center justify-center text-lg sm:text-xl flex-shrink-0 ${TINTS[st.tint].bg} ${TINTS[st.tint].text}`}>
              <i className={`ti ${st.icon}`} />
            </div>
          </div>
        ))}
      </div>

      {/* ── Filters ── */}
      <div className="flex items-center gap-3 flex-wrap mb-4">
        <div className="relative flex-1 min-w-[220px] max-w-[360px]">
          <i className="ti ti-search absolute left-3 top-1/2 -translate-y-1/2 text-[var(--outline)] text-[15px]" />
          <input
            type="text"
            placeholder="Search employees..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            suppressHydrationWarning
            className="w-full pl-9 pr-3 py-2.5 rounded-lg border border-[var(--outline-v)] bg-white text-[13px] text-[var(--on-bg)] placeholder:text-[var(--outline)] focus:border-[var(--primary)] focus:ring-2 focus:ring-[rgba(30,78,140,0.12)] transition-colors"
          />
        </div>

        <FilterSelect value={dept} onChange={setDept}>
          <option value="all">All Departments</option>
          {DEPARTMENT_OPTIONS.map(d => (
            <option key={d} value={d}>{d}</option>
          ))}
        </FilterSelect>

        <FilterSelect value={status} onChange={v => setStatus(v as "all" | EmployeeStatus)}>
          {STATUS_FILTERS.map(s => (
            <option key={s.value} value={s.value}>{s.label}</option>
          ))}
        </FilterSelect>
      </div>

      {/* ── Table ── */}
      <div className="bg-white rounded-xl border border-[var(--outline-v)] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse min-w-[860px]">
            <thead>
              <tr className="bg-[var(--bg-low)] border-b border-[var(--outline-v)]">
                {["Employee", "Department", "Designation", "Date of Joining", "Status", "Actions"].map(h => (
                  <th
                    key={h}
                    className="text-left text-[11px] font-semibold uppercase tracking-wide text-[var(--on-variant)] px-5 py-3 whitespace-nowrap"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-14 text-center">
                    <i className="ti ti-users-group text-4xl text-[var(--outline)] block mb-3" />
                    <p className="text-[13px] text-[var(--on-variant)]">No employees match your filters.</p>
                  </td>
                </tr>
              ) : (
                filtered.map(e => (
                  <tr
                    key={e.id}
                    onClick={() => open(e.id)}
                    className="border-b border-[var(--outline-v)] last:border-0 hover:bg-[var(--bg-low)] transition-colors cursor-pointer"
                  >
                    {/* Employee */}
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-3">
                        <Avatar text={initials(e.firstName, e.lastName)} size={38} color={avatarColor(e.department)} />
                        <div className="min-w-0">
                          <div className="text-[14px] font-semibold text-[var(--on-bg)] leading-tight truncate">
                            {fullName(e)}
                          </div>
                          <div className="text-[12px] text-[var(--on-variant)] truncate">{e.email}</div>
                        </div>
                      </div>
                    </td>
                    {/* Department */}
                    <td className="px-5 py-3.5 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[12px] font-medium ${deptTint(e.department).bg} ${deptTint(e.department).text}`}>
                        {e.department}
                      </span>
                    </td>
                    {/* Designation */}
                    <td className="px-5 py-3.5 text-[13px] text-[var(--on-bg)] whitespace-nowrap">{e.designation}</td>
                    {/* DOJ */}
                    <td className="px-5 py-3.5 text-[13px] text-[var(--on-variant)] whitespace-nowrap">{formatDate(e.dateOfJoining)}</td>
                    {/* Status */}
                    <td className="px-5 py-3.5"><StatusBadge status={e.status} /></td>
                    {/* Actions */}
                    <td className="px-5 py-3.5" onClick={ev => ev.stopPropagation()}>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => open(e.id)}
                          suppressHydrationWarning
                          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[12px] font-medium border border-[var(--outline-v)] text-[var(--on-bg)] bg-white hover:border-[var(--primary)] hover:text-[var(--primary)] transition-colors"
                        >
                          <i className="ti ti-eye text-[14px]" />
                          View
                        </button>
                        <button
                          onClick={() => open(e.id)}
                          title="Edit"
                          suppressHydrationWarning
                          className="w-8 h-8 flex items-center justify-center rounded-lg border border-[var(--outline-v)] text-[var(--on-variant)] bg-white hover:border-[var(--primary)] hover:text-[var(--primary)] transition-colors"
                        >
                          <i className="ti ti-pencil text-[14px]" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showWizard && (
        <AddEmployeeWizard
          existingCount={employees.length}
          onClose={() => setShowWizard(false)}
          onCreate={emp => {
            setEmployees([...getEmployees()]);
            setShowWizard(false);
          }}
        />
      )}
    </div>
  );
}

/** Compact pill-style filter select used in the toolbar. */
function FilterSelect({
  value,
  onChange,
  children,
}: {
  value: string;
  onChange: (v: string) => void;
  children: React.ReactNode;
}) {
  return (
    <select
      value={value}
      onChange={e => onChange(e.target.value)}
      suppressHydrationWarning
      className="px-3.5 py-2.5 pr-9 rounded-lg border border-[var(--outline-v)] bg-white text-[13px] font-medium text-[var(--on-bg)] focus:border-[var(--primary)] focus:ring-2 focus:ring-[rgba(30,78,140,0.12)] transition-colors appearance-none bg-no-repeat cursor-pointer"
      style={{
        backgroundImage:
          "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='none' stroke='%237c8aa3' stroke-width='2'><path d='M4 6l4 4 4-4'/></svg>\")",
        backgroundPosition: "right 10px center",
      }}
    >
      {children}
    </select>
  );
}
