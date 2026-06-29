"use client";

import { useState } from "react";

interface CalEvent { employee: string; type: string; color: string; from: number; to: number; }

const LEAVE_COLORS: Record<string, string> = {
  "Casual Leave": "#1e4e8c",
  "Earned Leave": "#1b8a6b",
  "Sick Leave":   "#b5651d",
  "Maternity":    "#ad95cf",
};

const EVENTS: Record<string, CalEvent[]> = {
  "2026-06": [
    { employee: "Arjun Mehta",  type: "Casual Leave", color: LEAVE_COLORS["Casual Leave"], from: 25, to: 26 },
    { employee: "Suresh Kumar", type: "Sick Leave",   color: LEAVE_COLORS["Sick Leave"],   from: 20, to: 20 },
    { employee: "Priya Sharma", type: "Casual Leave", color: LEAVE_COLORS["Casual Leave"], from: 28, to: 28 },
  ],
  "2026-07": [
    { employee: "Meena Iyer",  type: "Earned Leave", color: LEAVE_COLORS["Earned Leave"], from: 1,  to: 5  },
    { employee: "Rahul Singh", type: "Earned Leave", color: LEAVE_COLORS["Earned Leave"], from: 10, to: 14 },
  ],
};

const MONTH_NAMES = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const DAY_NAMES   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

export default function TeamCalendar() {
  const now = new Date();
  const [year,  setYear]  = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth());

  const key     = `${year}-${String(month + 1).padStart(2, "0")}`;
  const events  = EVENTS[key] ?? [];
  const firstDay     = new Date(year, month, 1).getDay();
  const daysInMonth  = new Date(year, month + 1, 0).getDate();

  function prev() { if (month === 0) { setMonth(11); setYear(y => y - 1); } else setMonth(m => m - 1); }
  function next() { if (month === 11) { setMonth(0); setYear(y => y + 1); } else setMonth(m => m + 1); }

  const cells: Array<number | null> = [
    ...Array<null>(firstDay).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];
  while (cells.length % 7 !== 0) cells.push(null);

  const today = now.getDate();
  const isCurrentMonth = now.getFullYear() === year && now.getMonth() === month;

  function dayEvents(day: number) { return events.filter(e => day >= e.from && day <= e.to); }

  return (
    <div className="w-full flex flex-col gap-5">

      {/* Legend */}
      <div className="flex gap-4 flex-wrap">
        {Object.entries(LEAVE_COLORS).map(([type, color]) => (
          <div key={type} className="flex items-center gap-2 text-xs text-gray-500">
            <div className="w-3 h-3 rounded" style={{ background: color }} />
            {type}
          </div>
        ))}
      </div>

      {/* Calendar card */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <button onClick={prev} className="w-8 h-8 rounded-lg border border-gray-200 flex items-center justify-center text-gray-500 hover:bg-gray-50 transition-colors">
            <i className="ti ti-chevron-left text-sm" />
          </button>
          <span className="text-sm font-bold text-[#1a2b4a]">{MONTH_NAMES[month]} {year}</span>
          <button onClick={next} className="w-8 h-8 rounded-lg border border-gray-200 flex items-center justify-center text-gray-500 hover:bg-gray-50 transition-colors">
            <i className="ti ti-chevron-right text-sm" />
          </button>
        </div>

        {/* Day name headers */}
        <div className="grid grid-cols-7 border-b border-gray-100 bg-gray-50">
          {DAY_NAMES.map(d => (
            <div key={d} className="py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wider">{d}</div>
          ))}
        </div>

        {/* Grid */}
        <div className="grid grid-cols-7">
          {cells.map((day, idx) => {
            const ev        = day ? dayEvents(day) : [];
            const isToday   = isCurrentMonth && day === today;
            const isWeekend = idx % 7 === 0 || idx % 7 === 6;
            const showRight = idx % 7 !== 6;
            const showBot   = idx < cells.length - 7;

            return (
              <div
                key={idx}
                className={[
                  "min-h-[90px] p-2",
                  showRight ? "border-r border-gray-100" : "",
                  showBot   ? "border-b border-gray-100" : "",
                  !day         ? "bg-gray-50"   :
                  isWeekend    ? "bg-gray-50/50" : "bg-white",
                ].join(" ")}
              >
                {day && (
                  <>
                    <div className={[
                      "w-6 h-6 rounded-full flex items-center justify-center text-xs mb-1 font-medium",
                      isToday ? "bg-[#1e4e8c] text-white font-bold" : isWeekend ? "text-gray-400" : "text-gray-600",
                    ].join(" ")}>
                      {day}
                    </div>
                    <div className="flex flex-col gap-0.5">
                      {ev.slice(0, 2).map((e, i) => (
                        <div
                          key={i}
                          title={`${e.employee} – ${e.type}`}
                          className="text-white text-[10px] font-medium px-1.5 py-0.5 rounded truncate"
                          style={{ background: e.color }}
                        >
                          {e.employee.split(" ")[0]}
                        </div>
                      ))}
                      {ev.length > 2 && <div className="text-[10px] text-gray-400 pl-1">+{ev.length - 2}</div>}
                    </div>
                  </>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Event list */}
      {events.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div className="flex items-center gap-2 px-6 py-4 border-b border-gray-100 text-sm font-semibold text-[#1a2b4a]">
            <i className="ti ti-calendar-event text-[#1e4e8c]" /> Leaves this month
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-100">
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-500 uppercase">Employee</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Type</th>
                  <th className="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase">From</th>
                  <th className="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase">To</th>
                  <th className="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Days</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {events.map((e, i) => (
                  <tr key={i} className="hover:bg-gray-50">
                    <td className="px-6 py-3.5 font-semibold text-[#1a2b4a]">{e.employee}</td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-2">
                        <div className="w-2.5 h-2.5 rounded-full" style={{ background: e.color }} />
                        <span className="text-gray-600">{e.type}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3.5 text-center text-gray-600">{MONTH_NAMES[month].slice(0,3)} {e.from}</td>
                    <td className="px-4 py-3.5 text-center text-gray-600">{MONTH_NAMES[month].slice(0,3)} {e.to}</td>
                    <td className="px-4 py-3.5 text-center font-bold text-[#1e4e8c]">{e.to - e.from + 1}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
