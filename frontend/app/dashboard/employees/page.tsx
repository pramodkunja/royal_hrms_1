"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import clientApi from "@/lib/clientApi";
import {
  fullName,
  initials,
  formatDate,
  deptTint,
  avatarColor,
  TINTS,
  type Employee,
  type EmployeeStatus,
} from "./_data";
import Avatar from "./_components/Avatar";
import StatusBadge from "./_components/StatusBadge";
import AddEmployeeModal from "./_components/AddEmployeeModal";

/* ── API response shape ─────────────────────────────────────── */
interface ApiEmployee {
  id: string; employee_id: string;
  first_name: string; last_name: string; full_name: string;
  email: string; phone: string;
  department: string; designation: string; branch: string;
  role: string; role_display: string;
  date_of_joining: string; is_active: boolean; status: string;
}

function apiToEmployee(u: ApiEmployee): Employee {
  return {
    id:            u.employee_id || u.id,
    code:          u.employee_id || u.id,
    firstName:     u.first_name,
    middleName:    "",
    lastName:      u.last_name,
    email:         u.email,
    phone:         u.phone,
    department:    u.department,
    designation:   u.designation,
    dateOfJoining: u.date_of_joining,
    dateOfBirth:   "",
    location:      u.branch,
    gender:        "male",
    status:        (u.status as EmployeeStatus) || (u.is_active ? "active" : "inactive"),
    details: {
      code:          u.employee_id,
      firstName:     u.first_name,
      middleName:    "",
      lastName:      u.last_name,
      gender:        "",
      dateOfBirth:   "",
      dateOfJoining: u.date_of_joining,
      department:    u.department,
      designation:   u.designation,
      branch:        u.branch,
      category:      "General",
      esiLocation:   "Corporate",
      metroTds:      "Metro",
      esiDispensary: "N/A",
      nationality:   "Indian",
      country:       "India",
      loginEmail:    u.email,
      personalEmail: u.email,
      ssRole:        u.role_display || "Employee",
      portalAccess:  "enabled",
      mobileNumber:  u.phone,
    },
    tables: {},
  };
}

const STATUS_FILTERS: { value: "all" | EmployeeStatus; label: string }[] = [
  { value: "all",         label: "All Status"  },
  { value: "active",      label: "Active"      },
  { value: "onboarding",  label: "Onboarding"  },
  { value: "inactive",    label: "Inactive"    },
];

const SEL_STYLE = {
  backgroundImage: "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='none' stroke='%237c8aa3' stroke-width='2'><path d='M4 6l4 4 4-4'/></svg>\")",
  backgroundPosition: "right 10px center",
};

export default function EmployeesPage() {
  const router = useRouter();

  const [employees,   setEmployees]   = useState<Employee[]>([]);
  const [loading,     setLoading]     = useState(true);
  const [fetchError,  setFetchError]  = useState("");
  const [search,      setSearch]      = useState("");
  const [dept,        setDept]        = useState("all");
  const [status,      setStatus]      = useState<"all" | EmployeeStatus>("all");
  const [showModal,   setShowModal]   = useState(false);

  /* unique departments from the loaded list */
  const deptOptions = useMemo(
    () => [...new Set(employees.map(e => e.department).filter(Boolean))].sort(),
    [employees],
  );

  const fetchEmployees = useCallback(async () => {
    setLoading(true);
    setFetchError("");
    try {
      const { data } = await clientApi.get<{ data: ApiEmployee[] }>("/employees/");
      setEmployees((data.data ?? []).map(apiToEmployee));
    } catch {
      setFetchError("Could not load employees. Please refresh.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchEmployees(); }, [fetchEmployees]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return employees.filter(e => {
      const matchesQ =
        !q ||
        fullName(e).toLowerCase().includes(q) ||
        e.email.toLowerCase().includes(q) ||
        e.code.toLowerCase().includes(q) ||
        e.designation.toLowerCase().includes(q);
      const matchesDept   = dept   === "all" || e.department === dept;
      const matchesStatus = status === "all" || e.status === status;
      return matchesQ && matchesDept && matchesStatus;
    });
  }, [employees, search, dept, status]);

  const stats = useMemo(() => {
    const active     = employees.filter(e => e.status === "active").length;
    const onboarding = employees.filter(e => e.status === "onboarding").length;
    const depts      = new Set(employees.map(e => e.department)).size;
    return [
      { label: "Total Employees", value: employees.length, icon: "ti-users",      tint: "primary"  as const },
      { label: "Active",          value: active,           icon: "ti-user-check", tint: "success"  as const },
      { label: "Onboarding",      value: onboarding,       icon: "ti-user-plus",  tint: "warn"     as const },
      { label: "Departments",     value: depts,            icon: "ti-building",   tint: "info"     as const },
    ];
  }, [employees]);

  function open(id: string) {
    router.push(`/dashboard/employees/${id}`);
  }

  return (
    <div>
      {/* ── Header ── */}
      <div className="page-header">
        <div>
          <div className="page-title">Employees</div>
          <div className="page-sub">All active and onboarding employees</div>
        </div>
        <button onClick={() => setShowModal(true)} suppressHydrationWarning
          className="btn btn-primary flex items-center gap-2">
          <i className="ti ti-plus text-[15px]" />
          Add Employee
        </button>
      </div>

      {/* ── Stats ── */}
      <div className="stats-grid mb-6">
        {stats.map(st => (
          <div key={st.label} className="stat-card">
            <div>
              <div className="stat-label">{st.label}</div>
              <div className="stat-value">{st.value}</div>
            </div>
            <div className={`stat-icon ${
              st.tint === "primary"  ? "si-primary"  :
              st.tint === "success"  ? "si-success"  :
              st.tint === "warn"     ? "si-warn"      :
              "si-info"
            }`}>
              <i className={`ti ${st.icon}`} />
            </div>
          </div>
        ))}
      </div>

      {/* ── Filters ── */}
      <div className="flex items-center gap-3 flex-wrap mb-4">
        <div className="relative flex-1 min-w-[220px] max-w-[360px]">
          <i className="ti ti-search absolute left-3 top-1/2 -translate-y-1/2 text-[var(--outline)] text-[15px]" />
          <input type="text" placeholder="Search employees..." value={search}
            onChange={e => setSearch(e.target.value)} suppressHydrationWarning
            className="w-full pl-9 pr-3 py-2.5 rounded-lg border border-[var(--outline-v)] bg-white text-[13px] text-[var(--on-bg)] placeholder:text-[var(--outline)] focus:border-[var(--primary)] focus:ring-2 focus:ring-[rgba(30,78,140,0.12)] transition-colors" />
        </div>

        <select value={dept} onChange={e => setDept(e.target.value)} suppressHydrationWarning
          className="px-3.5 py-2.5 pr-9 rounded-lg border border-[var(--outline-v)] bg-white text-[13px] font-medium text-[var(--on-bg)] focus:border-[var(--primary)] focus:ring-2 focus:ring-[rgba(30,78,140,0.12)] transition-colors appearance-none bg-no-repeat cursor-pointer"
          style={SEL_STYLE}>
          <option value="all">All Departments</option>
          {deptOptions.map(d => <option key={d} value={d}>{d}</option>)}
        </select>

        <select value={status} onChange={e => setStatus(e.target.value as "all" | EmployeeStatus)} suppressHydrationWarning
          className="px-3.5 py-2.5 pr-9 rounded-lg border border-[var(--outline-v)] bg-white text-[13px] font-medium text-[var(--on-bg)] focus:border-[var(--primary)] focus:ring-2 focus:ring-[rgba(30,78,140,0.12)] transition-colors appearance-none bg-no-repeat cursor-pointer"
          style={SEL_STYLE}>
          {STATUS_FILTERS.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
        </select>
      </div>

      {/* ── Table ── */}
      <div className="bg-white rounded-xl border border-[var(--outline-v)] overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-16 gap-2 text-[13px] text-[var(--on-variant)]">
            <i className="ti ti-loader-2 animate-spin text-[20px]" style={{ color: "var(--primary)" }} />
            Loading employees…
          </div>
        ) : fetchError ? (
          <div className="py-14 text-center">
            <i className="ti ti-alert-circle text-3xl block mb-2" style={{ color: "var(--error)" }} />
            <p className="text-[13px] text-[var(--on-variant)]">{fetchError}</p>
            <button onClick={fetchEmployees} suppressHydrationWarning
              className="mt-3 text-[13px] font-medium px-4 py-2 rounded-lg border border-[var(--outline-v)] text-[var(--primary)] hover:bg-[var(--bg-low)] transition-colors">
              Retry
            </button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse min-w-[860px]">
              <thead>
                <tr className="bg-[var(--bg-low)] border-b border-[var(--outline-v)]">
                  {["Employee", "Department", "Designation", "Date of Joining", "Status", "Actions"].map(h => (
                    <th key={h}
                      className="text-left text-[11px] font-semibold uppercase tracking-wide text-[var(--on-variant)] px-5 py-3 whitespace-nowrap">
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
                    <tr key={e.id} onClick={() => open(e.id)}
                      className="border-b border-[var(--outline-v)] last:border-0 hover:bg-[var(--bg-low)] transition-colors cursor-pointer">
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          <Avatar text={initials(e.firstName, e.lastName)} size={38} color={avatarColor(e.department)} />
                          <div className="min-w-0">
                            <div className="text-[14px] font-semibold text-[var(--on-bg)] leading-tight truncate">{fullName(e)}</div>
                            <div className="text-[12px] text-[var(--on-variant)] truncate">{e.email}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-5 py-3.5 whitespace-nowrap">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[12px] font-medium ${deptTint(e.department).bg} ${deptTint(e.department).text}`}>
                          {e.department || "—"}
                        </span>
                      </td>
                      <td className="px-5 py-3.5 text-[13px] text-[var(--on-bg)] whitespace-nowrap">{e.designation || "—"}</td>
                      <td className="px-5 py-3.5 text-[13px] text-[var(--on-variant)] whitespace-nowrap">{formatDate(e.dateOfJoining)}</td>
                      <td className="px-5 py-3.5"><StatusBadge status={e.status} /></td>
                      <td className="px-5 py-3.5" onClick={ev => ev.stopPropagation()}>
                        <div className="flex items-center gap-2">
                          <button onClick={() => open(e.id)} suppressHydrationWarning
                            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[12px] font-medium border border-[var(--outline-v)] text-[var(--on-bg)] bg-white hover:border-[var(--primary)] hover:text-[var(--primary)] transition-colors">
                            <i className="ti ti-eye text-[14px]" /> View
                          </button>
                          <button onClick={() => open(e.id)} suppressHydrationWarning
                            className="w-8 h-8 flex items-center justify-center rounded-lg border border-[var(--outline-v)] text-[var(--on-variant)] bg-white hover:border-[var(--primary)] hover:text-[var(--primary)] transition-colors">
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
        )}
      </div>

      {/* ── Modal ── */}
      {showModal && (
        <AddEmployeeModal
          onClose={() => setShowModal(false)}
          onCreated={() => {
            setShowModal(false);
            fetchEmployees();
          }}
        />
      )}
    </div>
  );
}
