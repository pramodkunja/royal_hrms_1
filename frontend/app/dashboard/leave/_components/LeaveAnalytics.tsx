"use client";

interface DeptStat  { dept: string; taken: number; pending: number; color: string; }
interface MonthStat { month: string; casual: number; earned: number; sick: number; }
interface Absentee  { name: string; dept: string; days: number; avatar: string; }

const DEPT_STATS: DeptStat[] = [
  { dept: "Engineering", taken: 42, pending: 5, color: "#1e4e8c" },
  { dept: "HR",          taken: 18, pending: 2, color: "#1b8a6b" },
  { dept: "Sales",       taken: 35, pending: 7, color: "#b5651d" },
  { dept: "Finance",     taken: 14, pending: 1, color: "#0e7c86" },
  { dept: "Marketing",   taken: 22, pending: 3, color: "#ad95cf" },
];

const MONTHLY: MonthStat[] = [
  { month: "Jan", casual: 12, earned: 8,  sick: 4 },
  { month: "Feb", casual: 9,  earned: 10, sick: 2 },
  { month: "Mar", casual: 15, earned: 12, sick: 6 },
  { month: "Apr", casual: 8,  earned: 9,  sick: 3 },
  { month: "May", casual: 11, earned: 14, sick: 5 },
  { month: "Jun", casual: 18, earned: 16, sick: 7 },
];

const ABSENTEES: Absentee[] = [
  { name: "Rahul Singh",  dept: "Engineering", days: 18, avatar: "RS" },
  { name: "Meena Iyer",   dept: "HR",          days: 15, avatar: "MI" },
  { name: "Arjun Mehta",  dept: "Sales",       days: 12, avatar: "AM" },
  { name: "Kavya Nair",   dept: "Marketing",   days: 11, avatar: "KN" },
  { name: "Suresh Kumar", dept: "Sales",       days: 9,  avatar: "SK" },
];

const AV_COLORS = ["#1e4e8c","#0e7c86","#1b8a6b","#b5651d","#ad95cf"];
function avColor(n: string) { return AV_COLORS[n.charCodeAt(0) % AV_COLORS.length]; }

const MAX_DEPT = Math.max(...DEPT_STATS.map(d => d.taken + d.pending));
const MAX_MO   = Math.max(...MONTHLY.map(m => m.casual + m.earned + m.sick));

export default function LeaveAnalytics() {
  const totalTaken   = DEPT_STATS.reduce((s, d) => s + d.taken, 0);
  const totalPending = DEPT_STATS.reduce((s, d) => s + d.pending, 0);

  return (
    <div className="w-full flex flex-col gap-5">

      {/* KPI row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { icon: "ti-beach",      bg: "bg-blue-50",   fg: "text-[#1e4e8c]", label: "Total Days Taken",    value: totalTaken  },
          { icon: "ti-clock",      bg: "bg-amber-50",  fg: "text-amber-600", label: "Pending Requests",    value: totalPending },
          { icon: "ti-chart-line", bg: "bg-green-50",  fg: "text-green-600", label: "Avg Days / Employee", value: "6.2"        },
          { icon: "ti-calendar-x", bg: "bg-red-50",    fg: "text-red-500",   label: "Rejected",            value: 4            },
        ].map(s => (
          <div key={s.label} className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 flex items-center gap-4">
            <div className={`w-11 h-11 rounded-xl ${s.bg} ${s.fg} flex items-center justify-center flex-shrink-0`}>
              <i className={`ti ${s.icon} text-xl`} />
            </div>
            <div>
              <p className="text-2xl font-extrabold text-[#1a2b4a] leading-none">{s.value}</p>
              <p className="text-xs text-gray-400 mt-1">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Two-col: Dept bars + Top absentees */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">

        {/* Dept breakdown */}
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <span className="text-sm font-semibold text-[#1a2b4a] flex items-center gap-2">
              <i className="ti ti-chart-bar text-[#1e4e8c]" /> Leave by Department
            </span>
            <span className="text-xs text-gray-400">Jan – Jun 2026</span>
          </div>
          <div className="p-6 flex flex-col gap-5">
            {DEPT_STATS.map(d => {
              const total = d.taken + d.pending;
              return (
                <div key={d.dept}>
                  <div className="flex justify-between mb-1.5">
                    <span className="text-sm font-semibold text-[#1a2b4a]">{d.dept}</span>
                    <span className="text-xs text-gray-400">{total}d</span>
                  </div>
                  <div className="h-2.5 w-full bg-gray-100 rounded-full overflow-hidden">
                    <div className="h-full flex">
                      <div className="h-full rounded-l-full transition-all duration-500" style={{ width: `${(d.taken / MAX_DEPT) * 100}%`, background: d.color }} />
                      <div className="h-full transition-all duration-500" style={{ width: `${(d.pending / MAX_DEPT) * 100}%`, background: `${d.color}55` }} />
                    </div>
                  </div>
                  <div className="flex gap-4 mt-1.5 text-xs text-gray-400">
                    <span className="flex items-center gap-1">
                      <span className="w-2.5 h-2.5 rounded-sm inline-block" style={{ background: d.color }} />{d.taken} taken
                    </span>
                    <span className="flex items-center gap-1">
                      <span className="w-2.5 h-2.5 rounded-sm inline-block" style={{ background: `${d.color}55` }} />{d.pending} pending
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Top absentees */}
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <span className="text-sm font-semibold text-[#1a2b4a] flex items-center gap-2">
              <i className="ti ti-users text-[#1e4e8c]" /> Top Leave Takers
            </span>
            <span className="text-xs text-gray-400">YTD 2026</span>
          </div>
          <div>
            {ABSENTEES.map((a, i) => {
              const color = avColor(a.name);
              return (
                <div key={a.name} className={`flex items-center gap-4 px-6 py-4 ${i < ABSENTEES.length - 1 ? "border-b border-gray-50" : ""} hover:bg-gray-50 transition-colors`}>
                  <span className="text-sm font-bold text-gray-300 w-5 text-center">{i + 1}</span>
                  <div
                    className="w-9 h-9 rounded-xl flex items-center justify-center font-bold text-xs flex-shrink-0"
                    style={{ background: `${color}22`, color }}
                  >
                    {a.avatar}
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-[#1a2b4a]">{a.name}</p>
                    <p className="text-xs text-gray-400">{a.dept}</p>
                  </div>
                  <span className="text-base font-extrabold text-[#1e4e8c]">{a.days}d</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Monthly trend bar chart */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 flex-wrap gap-3">
          <span className="text-sm font-semibold text-[#1a2b4a] flex items-center gap-2">
            <i className="ti ti-chart-line text-[#1e4e8c]" /> Monthly Trend — Leave Days
          </span>
          <div className="flex gap-4 text-xs text-gray-400">
            {[{ label: "Casual", color: "#1e4e8c" }, { label: "Earned", color: "#1b8a6b" }, { label: "Sick", color: "#b5651d" }].map(l => (
              <span key={l.label} className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-sm" style={{ background: l.color }} />{l.label}
              </span>
            ))}
          </div>
        </div>
        <div className="px-6 pb-4 pt-6 flex gap-3 items-end" style={{ height: 200 }}>
          {MONTHLY.map(m => {
            const total = m.casual + m.earned + m.sick;
            return (
              <div key={m.month} className="flex-1 flex flex-col items-center gap-1" style={{ height: "100%" }}>
                <div className="flex flex-col justify-end w-full flex-1 gap-px" style={{ minWidth: 0 }}>
                  <div style={{ height: `${(m.sick   / MAX_MO) * 120}px`, background: "#b5651d", borderRadius: "3px 3px 0 0" }} title={`Sick: ${m.sick}`} />
                  <div style={{ height: `${(m.earned / MAX_MO) * 120}px`, background: "#1b8a6b" }} title={`Earned: ${m.earned}`} />
                  <div style={{ height: `${(m.casual / MAX_MO) * 120}px`, background: "#1e4e8c" }} title={`Casual: ${m.casual}`} />
                </div>
                <p className="text-xs text-gray-400 mt-1">{m.month}</p>
                <p className="text-xs font-bold text-[#1e4e8c]">{total}</p>
              </div>
            );
          })}
        </div>
      </div>

    </div>
  );
}
