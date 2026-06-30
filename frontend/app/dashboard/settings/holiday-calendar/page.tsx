"use client";

import { useState, useMemo } from "react";
import { useRouter } from "next/navigation";

// ─── Types ────────────────────────────────────────────────────────────────────

type HolidayType = "national" | "regional" | "company";
type FilterTab   = HolidayType | "all" | "optional";
type ViewMode    = "list" | "calendar";

interface Holiday {
  id:                  number;
  name:                string;
  date:                string;
  type:                HolidayType;
  is_optional:         boolean;
  applicable_branches: string;
  is_active:           boolean;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const BRANCHES    = ["All Branches", "Head Office", "Mumbai", "Chennai", "Hyderabad", "Bengaluru", "Delhi"];
const YEARS       = [2024, 2025, 2026, 2027, 2028];
const MONTH_NAMES = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const MONTH_SHORT = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const DAY_SHORT   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

const TYPE_STYLES: Record<HolidayType, { badge: string; pill: string; cal: string; dot: string }> = {
  national: { badge: "bg-blue-100 text-blue-700",   pill: "bg-blue-600",   cal: "bg-blue-50 border-l-2 border-blue-400 text-blue-800",   dot: "bg-blue-500"  },
  regional: { badge: "bg-teal-100 text-teal-700",   pill: "bg-teal-600",   cal: "bg-teal-50 border-l-2 border-teal-400 text-teal-800",   dot: "bg-teal-500"  },
  company:  { badge: "bg-amber-100 text-amber-700", pill: "bg-amber-500",  cal: "bg-amber-50 border-l-2 border-amber-400 text-amber-800", dot: "bg-amber-500" },
};

const BLANK: Omit<Holiday, "id"> = {
  name: "", date: "", type: "national", is_optional: false, applicable_branches: "All", is_active: true,
};

// ─── Seed data ────────────────────────────────────────────────────────────────

const SEED: Holiday[] = [
  { id:  1, name: "New Year's Day",         date: "2026-01-01", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id:  2, name: "Republic Day",           date: "2026-01-26", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id:  3, name: "Pongal",                 date: "2026-01-14", type: "regional", is_optional: false, applicable_branches: "Chennai, Hyderabad",    is_active: true  },
  { id:  4, name: "Holi",                   date: "2026-03-03", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id:  5, name: "Ugadi",                  date: "2026-03-19", type: "regional", is_optional: false, applicable_branches: "Hyderabad, Bengaluru",  is_active: true  },
  { id:  6, name: "Eid ul-Fitr",            date: "2026-03-31", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id:  7, name: "Good Friday",            date: "2026-04-03", type: "national", is_optional: true,  applicable_branches: "All",                  is_active: true  },
  { id:  8, name: "Labour Day",             date: "2026-05-01", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id:  9, name: "Company Foundation Day", date: "2026-06-15", type: "company",  is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 10, name: "Independence Day",       date: "2026-08-15", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 11, name: "Janmashtami",            date: "2026-08-25", type: "national", is_optional: true,  applicable_branches: "All",                  is_active: true  },
  { id: 12, name: "Team Building Day",      date: "2026-09-12", type: "company",  is_optional: true,  applicable_branches: "All",                  is_active: true  },
  { id: 13, name: "Gandhi Jayanti",         date: "2026-10-02", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 14, name: "Dussehra",              date: "2026-10-14", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 15, name: "Diwali",               date: "2026-11-03", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 16, name: "Christmas Day",         date: "2026-12-25", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 17, name: "New Year's Eve",        date: "2026-12-31", type: "company",  is_optional: true,  applicable_branches: "Head Office, Mumbai",   is_active: false },
  { id: 18, name: "New Year's Day",         date: "2025-01-01", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 19, name: "Republic Day",           date: "2025-01-26", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 20, name: "Holi",                   date: "2025-03-14", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 21, name: "Independence Day",       date: "2025-08-15", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 22, name: "Diwali",               date: "2025-10-20", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
  { id: 23, name: "Christmas Day",         date: "2025-12-25", type: "national", is_optional: false, applicable_branches: "All",                  is_active: true  },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function fmtDate(iso: string) {
  if (!iso) return "—";
  const [y, m, d] = iso.split("-");
  return `${parseInt(d)} ${MONTH_SHORT[parseInt(m) - 1]} ${y}`;
}

function dayName(iso: string) {
  return iso ? new Date(iso + "T12:00:00").toLocaleDateString("en-US", { weekday: "short" }) : "";
}

function calendarWeeks(year: number, month: number) {
  const firstDay = new Date(year, month, 1).getDay();
  const totalDays = new Date(year, month + 1, 0).getDate();
  const cells: (number | null)[] = Array(firstDay).fill(null);
  for (let d = 1; d <= totalDays; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);
  const weeks: (number | null)[][] = [];
  for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
  return weeks;
}

function isoDate(year: number, month: number, day: number) {
  return `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function HolidayCalendarPage() {
  const router = useRouter();

  const [holidays,  setHolidays]  = useState<Holiday[]>(SEED);
  const [year,      setYear]      = useState(2026);
  const [view,      setView]      = useState<ViewMode>("list");
  const [filterTab, setFilterTab] = useState<FilterTab>("all");
  const [fBranch,   setFBranch]   = useState("All Branches");
  const [fType,     setFType]     = useState<HolidayType | "all">("all");
  const [fMonth,    setFMonth]    = useState<number | "all">("all");
  const [search,    setSearch]    = useState("");
  const [calMonth,  setCalMonth]  = useState(0);
  const [page,      setPage]      = useState(1);

  const [modal,       setModal]       = useState<"add" | "edit" | "view" | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Holiday | null>(null);
  const [editing,     setEditing]     = useState<Holiday | null>(null);
  const [form,        setForm]        = useState<Omit<Holiday, "id">>(BLANK);
  const [errors,      setErrors]      = useState<Record<string, string>>({});
  const [saving,      setSaving]      = useState(false);

  const PAGE_SIZE = 10;

  const yearHolidays = useMemo(() =>
    holidays.filter(h => h.date.startsWith(year.toString())),
    [holidays, year]
  );

  const stats = useMemo(() => ({
    total:    yearHolidays.length,
    national: yearHolidays.filter(h => h.type === "national").length,
    regional: yearHolidays.filter(h => h.type === "regional").length,
    company:  yearHolidays.filter(h => h.type === "company").length,
    optional: yearHolidays.filter(h => h.is_optional).length,
  }), [yearHolidays]);

  const filtered = useMemo(() => {
    let list = yearHolidays;
    if (filterTab === "optional") list = list.filter(h => h.is_optional);
    else if (filterTab !== "all") list = list.filter(h => h.type === filterTab);
    if (fType !== "all") list = list.filter(h => h.type === fType);
    if (fBranch !== "All Branches") list = list.filter(h => h.applicable_branches === "All" || h.applicable_branches.includes(fBranch));
    if (fMonth !== "all") list = list.filter(h => parseInt(h.date.split("-")[1]) - 1 === fMonth);
    if (search.trim()) list = list.filter(h => h.name.toLowerCase().includes(search.toLowerCase()));
    return [...list].sort((a, b) => a.date.localeCompare(b.date));
  }, [yearHolidays, filterTab, fType, fBranch, fMonth, search]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageRows   = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const calHolidays = useMemo(() =>
    yearHolidays.filter(h => parseInt(h.date.split("-")[1]) - 1 === calMonth),
    [yearHolidays, calMonth]
  );

  function openAdd() {
    setEditing(null); setForm(BLANK); setErrors({}); setModal("add");
  }
  function openEdit(h: Holiday) {
    setEditing(h); const { id: _id, ...rest } = h; void _id;
    setForm(rest); setErrors({}); setModal("edit");
  }
  function openView(h: Holiday) { setEditing(h); setModal("view"); }
  function closeModal() { setModal(null); setEditing(null); }

  function validate() {
    const e: Record<string, string> = {};
    if (!form.name.trim()) e.name = "Holiday name is required.";
    if (!form.date)        e.date = "Date is required.";
    setErrors(e); return Object.keys(e).length === 0;
  }

  function save() {
    if (!validate()) return;
    setSaving(true);
    setTimeout(() => {
      if (modal === "add")  setHolidays(prev => [...prev, { ...form, id: Date.now() }]);
      else if (editing)     setHolidays(prev => prev.map(h => h.id === editing.id ? { ...form, id: editing.id } : h));
      setSaving(false); closeModal();
    }, 400);
  }

  function confirmDelete() {
    if (!deleteTarget) return;
    setHolidays(prev => prev.filter(h => h.id !== deleteTarget.id));
    setDeleteTarget(null);
  }

  function toggleActive(id: number) {
    setHolidays(prev => prev.map(h => h.id === id ? { ...h, is_active: !h.is_active } : h));
  }

  function setField(key: keyof typeof form, value: string | boolean) {
    setErrors(prev => { const n = { ...prev }; delete n[key]; return n; });
    setForm(prev => ({ ...prev, [key]: value }));
  }

  const filterTabs: Array<{ id: FilterTab; label: string; count: number }> = [
    { id: "all",      label: "All",      count: stats.total    },
    { id: "national", label: "National", count: stats.national },
    { id: "regional", label: "Regional", count: stats.regional },
    { id: "company",  label: "Company",  count: stats.company  },
    { id: "optional", label: "Optional", count: stats.optional },
  ];

  const INPUT = "w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 bg-white outline-none transition focus:border-blue-600 focus:ring-2 focus:ring-blue-100";
  const INPUT_ERR = "w-full border border-red-400 rounded-lg px-3 py-2 text-sm bg-red-50 outline-none";

  // ── Calendar view ──────────────────────────────────────────────────────────
  const weeks = calendarWeeks(year, calMonth);
  const calMap = Object.fromEntries(calHolidays.map(h => [h.date, h]));

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <>
      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="page-header">
        <div>
          <div className="page-title">Holiday Calendar</div>
          <div className="page-sub">Manage national, regional, and company holidays</div>
        </div>
        <div className="page-actions">
          <button className="btn btn-ghost" onClick={() => router.push("/dashboard/settings")}>
            <i className="ti ti-arrow-left" /> Back
          </button>
          <button className="btn btn-filled" onClick={openAdd}>
            <i className="ti ti-plus" /> Add Holiday
          </button>
        </div>
      </div>

      {/* ── Year navigator + quick filters ───────────────────────────────── */}
      <div className="flex flex-wrap items-center justify-between gap-3 mb-5">
        {/* Year nav */}
        <div className="flex items-center gap-1 bg-white border border-gray-200 rounded-xl px-2 py-1.5 shadow-sm">
          <button onClick={() => { setYear(y => y - 1); setPage(1); }}
            className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-500 transition-colors">
            <i className="ti ti-chevron-left text-sm" />
          </button>
          <select
            value={year} onChange={e => { setYear(Number(e.target.value)); setPage(1); }}
            className="text-sm font-bold text-gray-800 bg-transparent border-none outline-none px-1 cursor-pointer"
          >
            {YEARS.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <button onClick={() => { setYear(y => y + 1); setPage(1); }}
            className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-500 transition-colors">
            <i className="ti ti-chevron-right text-sm" />
          </button>
        </div>

        {/* Right controls */}
        <div className="flex items-center gap-2 flex-wrap">
          <select value={fBranch} onChange={e => { setFBranch(e.target.value); setPage(1); }}
            className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white outline-none focus:border-blue-500 text-gray-700 cursor-pointer">
            {BRANCHES.map(b => <option key={b}>{b}</option>)}
          </select>
          <div className="relative">
            <i className="ti ti-search absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm" />
            <input
              value={search} onChange={e => { setSearch(e.target.value); setPage(1); }}
              placeholder="Search holidays…"
              className="pl-8 pr-3 py-2 text-sm border border-gray-200 rounded-lg bg-white outline-none focus:border-blue-500 w-48"
            />
          </div>
        </div>
      </div>

      {/* ── Stats cards ──────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-5">
        {[
          { icon: "ti-calendar-event", color: "text-blue-700",   bg: "bg-blue-50",   label: "Total Holidays",   value: stats.total    },
          { icon: "ti-flag",           color: "text-blue-600",   bg: "bg-blue-50",   label: "National",         value: stats.national },
          { icon: "ti-map-pin",        color: "text-teal-600",   bg: "bg-teal-50",   label: "Regional",         value: stats.regional },
          { icon: "ti-building",       color: "text-amber-600",  bg: "bg-amber-50",  label: "Company",          value: stats.company  },
          { icon: "ti-calendar-check", color: "text-purple-600", bg: "bg-purple-50", label: "Optional",         value: stats.optional },
        ].map(s => (
          <div key={s.label} className="bg-white rounded-2xl border border-gray-200 shadow-sm px-4 py-4 flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl ${s.bg} ${s.color} flex items-center justify-center flex-shrink-0`}>
              <i className={`ti ${s.icon} text-lg`} />
            </div>
            <div>
              <div className="text-2xl font-extrabold text-gray-800 leading-none">{s.value}</div>
              <div className="text-xs text-gray-400 mt-0.5">{s.label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* ── Filter tabs ───────────────────────────────────────────────────── */}
      <div className="flex items-center gap-2 flex-wrap mb-4">
        {filterTabs.map(t => (
          <button
            key={t.id}
            onClick={() => { setFilterTab(t.id); setPage(1); }}
            className={[
              "px-4 py-1.5 rounded-full text-sm font-medium border transition-all",
              filterTab === t.id
                ? "bg-blue-700 text-white border-blue-700"
                : "bg-white text-gray-500 border-gray-200 hover:border-blue-600 hover:text-blue-600",
            ].join(" ")}
          >
            {t.label}
            <span className={[
              "ml-1.5 inline-flex items-center justify-center min-w-[18px] h-[18px] rounded-full text-xs font-bold px-1",
              filterTab === t.id ? "bg-white text-blue-700" : "bg-gray-100 text-gray-500",
            ].join(" ")}>
              {t.count}
            </span>
          </button>
        ))}

        {/* View toggle — pushed to right */}
        <div className="ml-auto flex items-center gap-1 bg-gray-100 rounded-xl p-1">
          <button onClick={() => setView("list")}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all flex items-center gap-1.5 ${view === "list" ? "bg-white shadow-sm text-blue-700" : "text-gray-500 hover:text-gray-700"}`}>
            <i className="ti ti-list text-sm" /> List
          </button>
          <button onClick={() => setView("calendar")}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all flex items-center gap-1.5 ${view === "calendar" ? "bg-white shadow-sm text-blue-700" : "text-gray-500 hover:text-gray-700"}`}>
            <i className="ti ti-calendar-month text-sm" /> Calendar
          </button>
        </div>
      </div>

      {/* ── Additional filters row ────────────────────────────────────────── */}
      <div className="flex flex-wrap gap-2 mb-4">
        <select value={fType} onChange={e => { setFType(e.target.value as HolidayType | "all"); setPage(1); }}
          className="text-xs border border-gray-200 rounded-lg px-3 py-1.5 bg-white outline-none focus:border-blue-500 text-gray-600 cursor-pointer">
          <option value="all">All Types</option>
          <option value="national">National</option>
          <option value="regional">Regional</option>
          <option value="company">Company</option>
        </select>
        <select value={fMonth === "all" ? "all" : fMonth} onChange={e => { setFMonth(e.target.value === "all" ? "all" : parseInt(e.target.value)); setPage(1); }}
          className="text-xs border border-gray-200 rounded-lg px-3 py-1.5 bg-white outline-none focus:border-blue-500 text-gray-600 cursor-pointer">
          <option value="all">All Months</option>
          {MONTH_NAMES.map((m, i) => <option key={i} value={i}>{m}</option>)}
        </select>
        {(search || fBranch !== "All Branches" || fType !== "all" || fMonth !== "all") && (
          <button onClick={() => { setSearch(""); setFBranch("All Branches"); setFType("all"); setFMonth("all"); setPage(1); }}
            className="text-xs px-3 py-1.5 rounded-lg border border-red-200 text-red-500 bg-red-50 hover:bg-red-100 transition-colors flex items-center gap-1">
            <i className="ti ti-x text-xs" /> Clear Filters
          </button>
        )}
        <span className="ml-auto text-xs text-gray-400 self-center">{filtered.length} holiday{filtered.length !== 1 ? "s" : ""}</span>
      </div>

      {/* ── LIST VIEW ─────────────────────────────────────────────────────── */}
      {view === "list" && (
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          {filtered.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3 text-gray-400">
              <i className="ti ti-calendar-off text-5xl text-gray-300" />
              <p className="text-sm font-medium">No holidays found for {year}</p>
              <button onClick={openAdd} className="mt-1 text-sm text-blue-600 hover:underline">+ Add the first holiday</button>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50 border-b border-gray-100">
                      {["Holiday Name","Date","Day","Holiday Type","Mandatory / Optional","Applicable Branches","Status","Actions"].map(col => (
                        <th key={col} className="px-4 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider whitespace-nowrap">
                          {col}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {pageRows.map((h, idx) => (
                      <tr key={h.id} className={`transition-colors hover:bg-gray-50 ${idx < pageRows.length - 1 ? "border-b border-gray-100" : ""}`}>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <span className={`w-2 h-2 rounded-full flex-shrink-0 ${TYPE_STYLES[h.type].dot}`} />
                            <span className="font-semibold text-gray-800 text-sm">{h.name}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-700 whitespace-nowrap">{fmtDate(h.date)}</td>
                        <td className="px-4 py-3">
                          <span className="text-xs font-medium text-gray-500 bg-gray-100 px-2 py-0.5 rounded">{dayName(h.date)}</span>
                        </td>
                        <td className="px-4 py-3">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize ${TYPE_STYLES[h.type].badge}`}>
                            {h.type}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          {h.is_optional
                            ? <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-700">Optional</span>
                            : <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-green-100 text-green-700">Mandatory</span>
                          }
                        </td>
                        <td className="px-4 py-3 text-xs text-gray-500 max-w-[160px] truncate">{h.applicable_branches}</td>
                        <td className="px-4 py-3">
                          <button onClick={() => toggleActive(h.id)}
                            className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold transition-colors ${h.is_active ? "bg-green-100 text-green-700 hover:bg-green-200" : "bg-gray-100 text-gray-500 hover:bg-gray-200"}`}>
                            <span className={`w-1.5 h-1.5 rounded-full ${h.is_active ? "bg-green-500" : "bg-gray-400"}`} />
                            {h.is_active ? "Active" : "Inactive"}
                          </button>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-1.5">
                            <button onClick={() => openView(h)}
                              className="w-7 h-7 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:border-blue-400 hover:text-blue-600 transition-colors">
                              <i className="ti ti-eye text-xs" />
                            </button>
                            <button onClick={() => openEdit(h)}
                              className="w-7 h-7 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:border-blue-400 hover:text-blue-600 transition-colors">
                              <i className="ti ti-edit text-xs" />
                            </button>
                            <button onClick={() => setDeleteTarget(h)}
                              className="w-7 h-7 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:border-red-400 hover:text-red-600 transition-colors">
                              <i className="ti ti-trash text-xs" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-5 py-3 border-t border-gray-100 bg-gray-50">
                  <span className="text-xs text-gray-500">
                    Showing {(page - 1) * PAGE_SIZE + 1}–{Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length}
                  </span>
                  <div className="flex items-center gap-1">
                    <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                      className="w-7 h-7 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 disabled:opacity-40 hover:border-blue-400 hover:text-blue-600 transition-colors">
                      <i className="ti ti-chevron-left text-xs" />
                    </button>
                    {Array.from({ length: totalPages }, (_, i) => i + 1).map(p => (
                      <button key={p} onClick={() => setPage(p)}
                        className={`w-7 h-7 flex items-center justify-center rounded-lg text-xs font-semibold transition-colors ${p === page ? "bg-blue-700 text-white border border-blue-700" : "border border-gray-200 text-gray-500 hover:border-blue-400 hover:text-blue-600"}`}>
                        {p}
                      </button>
                    ))}
                    <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
                      className="w-7 h-7 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 disabled:opacity-40 hover:border-blue-400 hover:text-blue-600 transition-colors">
                      <i className="ti ti-chevron-right text-xs" />
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* ── CALENDAR VIEW ─────────────────────────────────────────────────── */}
      {view === "calendar" && (
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          {/* Month navigator */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <button onClick={() => setCalMonth(m => Math.max(0, m - 1))} disabled={calMonth === 0}
              className="w-8 h-8 flex items-center justify-center rounded-xl border border-gray-200 text-gray-500 disabled:opacity-30 hover:border-blue-400 hover:text-blue-600 transition-colors">
              <i className="ti ti-chevron-left text-sm" />
            </button>
            <div className="text-center">
              <div className="text-base font-bold text-gray-800">{MONTH_NAMES[calMonth]} {year}</div>
              <div className="text-xs text-gray-400 mt-0.5">{calHolidays.length} holiday{calHolidays.length !== 1 ? "s" : ""} this month</div>
            </div>
            <button onClick={() => setCalMonth(m => Math.min(11, m + 1))} disabled={calMonth === 11}
              className="w-8 h-8 flex items-center justify-center rounded-xl border border-gray-200 text-gray-500 disabled:opacity-30 hover:border-blue-400 hover:text-blue-600 transition-colors">
              <i className="ti ti-chevron-right text-sm" />
            </button>
          </div>

          {/* Day headers */}
          <div className="grid grid-cols-7 border-b border-gray-100">
            {DAY_SHORT.map(d => (
              <div key={d} className={`py-2 text-center text-xs font-bold uppercase tracking-wider ${d === "Sun" ? "text-red-400" : "text-gray-400"}`}>{d}</div>
            ))}
          </div>

          {/* Calendar grid */}
          <div>
            {weeks.map((week, wi) => (
              <div key={wi} className="grid grid-cols-7 border-b border-gray-50 last:border-b-0">
                {week.map((day, di) => {
                  const iso = day ? isoDate(year, calMonth, day) : "";
                  const holiday = iso ? calMap[iso] : null;
                  const isSun = di === 0;
                  return (
                    <div key={di} className={`min-h-[80px] p-2 border-r border-gray-50 last:border-r-0 ${!day ? "bg-gray-50/50" : ""}`}>
                      {day && (
                        <>
                          <span className={`text-xs font-semibold ${isSun ? "text-red-400" : "text-gray-600"} ${holiday ? "w-6 h-6 flex items-center justify-center rounded-full bg-blue-700 text-white text-xs" : ""}`}>
                            {day}
                          </span>
                          {holiday && (
                            <div className={`mt-1 px-1.5 py-1 rounded text-xs font-medium leading-tight ${TYPE_STYLES[holiday.type].cal} cursor-pointer`}
                              onClick={() => openView(holiday)}>
                              <div className="truncate">{holiday.name}</div>
                              {holiday.is_optional && <div className="text-purple-500 text-[10px]">Optional</div>}
                            </div>
                          )}
                        </>
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>

          {/* Month holiday list */}
          {calHolidays.length > 0 && (
            <div className="border-t border-gray-100 px-5 py-4">
              <div className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">Holidays in {MONTH_NAMES[calMonth]}</div>
              <div className="flex flex-col gap-2">
                {calHolidays.sort((a, b) => a.date.localeCompare(b.date)).map(h => (
                  <div key={h.id} className="flex items-center gap-3 text-sm">
                    <span className={`w-2 h-2 rounded-full flex-shrink-0 ${TYPE_STYLES[h.type].dot}`} />
                    <span className="font-semibold text-gray-700 w-[160px] truncate">{h.name}</span>
                    <span className="text-gray-400">{fmtDate(h.date)}</span>
                    <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold capitalize ${TYPE_STYLES[h.type].badge}`}>{h.type}</span>
                    {h.is_optional && <span className="inline-flex px-2 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-700">Optional</span>}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Type legend ───────────────────────────────────────────────────── */}
      <div className="flex flex-wrap gap-4 mt-4 px-1">
        {(["national","regional","company"] as HolidayType[]).map(t => (
          <div key={t} className="flex items-center gap-1.5 text-xs text-gray-500">
            <span className={`w-2.5 h-2.5 rounded-full ${TYPE_STYLES[t].dot}`} />
            <span className="capitalize font-medium">{t}</span>
          </div>
        ))}
        <div className="flex items-center gap-1.5 text-xs text-gray-500">
          <span className="w-2.5 h-2.5 rounded-full bg-purple-400" />
          <span className="font-medium">Optional</span>
        </div>
      </div>

      {/* ── View Holiday Modal ────────────────────────────────────────────── */}
      {modal === "view" && editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <div className="flex items-center gap-2">
                <span className={`w-3 h-3 rounded-full ${TYPE_STYLES[editing.type].dot}`} />
                <span className="text-sm font-bold text-gray-800">{editing.name}</span>
              </div>
              <button onClick={closeModal} className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-400 transition-colors">
                <i className="ti ti-x text-sm" />
              </button>
            </div>
            <div className="px-6 py-5 grid grid-cols-2 gap-4">
              {[
                ["Date",     fmtDate(editing.date)],
                ["Day",      dayName(editing.date)],
                ["Type",     editing.type],
                ["Applies",  editing.is_optional ? "Optional" : "Mandatory"],
                ["Status",   editing.is_active ? "Active" : "Inactive"],
                ["Branches", editing.applicable_branches],
              ].map(([label, value]) => (
                <div key={label}>
                  <div className="text-xs text-gray-400 mb-0.5">{label}</div>
                  <div className="text-sm font-semibold text-gray-700 capitalize">{value}</div>
                </div>
              ))}
            </div>
            <div className="flex gap-2 px-6 pb-5">
              <button onClick={() => { closeModal(); openEdit(editing); }}
                className="flex-1 py-2 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors flex items-center justify-center gap-2">
                <i className="ti ti-edit" /> Edit
              </button>
              <button onClick={closeModal}
                className="flex-1 py-2 rounded-xl bg-blue-700 text-white text-sm font-medium hover:bg-blue-800 transition-colors">
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Add / Edit Modal ──────────────────────────────────────────────── */}
      {(modal === "add" || modal === "edit") && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <span className="text-sm font-bold text-gray-800">
                {modal === "add" ? "Add Holiday" : `Edit: ${editing?.name}`}
              </span>
              <button onClick={closeModal} className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-400 transition-colors">
                <i className="ti ti-x text-sm" />
              </button>
            </div>
            <div className="px-6 py-5 flex flex-col gap-4">
              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1.5">Holiday Name *</label>
                <input className={errors.name ? INPUT_ERR : INPUT} value={form.name}
                  onChange={e => setField("name", e.target.value)} placeholder="e.g. Independence Day" autoFocus maxLength={80} />
                {errors.name && <p className="text-xs text-red-500 mt-1">{errors.name}</p>}
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1.5">Date *</label>
                  <input className={errors.date ? INPUT_ERR : INPUT} type="date" value={form.date}
                    onChange={e => setField("date", e.target.value)} />
                  {errors.date && <p className="text-xs text-red-500 mt-1">{errors.date}</p>}
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1.5">Type</label>
                  <select className={INPUT} value={form.type} onChange={e => setField("type", e.target.value)}>
                    <option value="national">National</option>
                    <option value="regional">Regional</option>
                    <option value="company">Company</option>
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1.5">Applicable Branches</label>
                <input className={INPUT} value={form.applicable_branches}
                  onChange={e => setField("applicable_branches", e.target.value)}
                  placeholder="All, or comma-separated branch names" />
              </div>
              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input type="checkbox" checked={form.is_optional} onChange={e => setField("is_optional", e.target.checked)}
                    className="w-4 h-4 rounded border-gray-300 text-blue-600" />
                  <span className="text-sm text-gray-700">Optional holiday</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input type="checkbox" checked={form.is_active} onChange={e => setField("is_active", e.target.checked)}
                    className="w-4 h-4 rounded border-gray-300 text-blue-600" />
                  <span className="text-sm text-gray-700">Active</span>
                </label>
              </div>
            </div>
            <div className="flex justify-end gap-2 px-6 pb-5">
              <button onClick={closeModal}
                className="px-4 py-2 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button onClick={save} disabled={saving}
                className="px-5 py-2 rounded-xl text-sm font-semibold text-white transition-colors flex items-center gap-2"
                style={{ background: saving ? "#7fa3c8" : "#1e4e8c" }}>
                {saving ? <><i className="ti ti-loader-2 animate-spin" /> Saving…</> : modal === "add" ? "Add Holiday" : "Save Changes"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Delete Confirmation Modal ──────────────────────────────────────── */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">
            <div className="px-6 pt-6 pb-4 text-center">
              <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-4">
                <i className="ti ti-trash text-xl text-red-600" />
              </div>
              <p className="text-sm font-bold text-gray-800 mb-1">Delete Holiday?</p>
              <p className="text-sm text-gray-500">
                <strong className="text-gray-700">{deleteTarget.name}</strong> ({fmtDate(deleteTarget.date)}) will be permanently removed.
              </p>
            </div>
            <div className="flex gap-2 px-6 pb-5">
              <button onClick={() => setDeleteTarget(null)}
                className="flex-1 py-2 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button onClick={confirmDelete}
                className="flex-1 py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white text-sm font-semibold transition-colors">
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
