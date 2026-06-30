"use client";

import { useState, useMemo } from "react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Duration    = "full_day" | "half_morning" | "half_afternoon";
type LTKey       = "casual" | "earned" | "sick" | "lwp" | "maternity" | "paternity";
type SubmitState = "idle" | "saving" | "submitted";

interface LeaveType {
  key:         LTKey;
  label:       string;
  shortLabel:  string;
  icon:        string;
  color:       string;
  bg:          string;
  balance:     number;
  total:       number;
  policy:      string;
  requiresDoc: boolean;
}

interface LeaveForm {
  leave_type:   LTKey;
  duration:     Duration;
  from_date:    string;
  to_date:      string;
  reason:       string;
  contact:      string;
  handover_to:  string;
  handover_notes: string;
  doc_name:     string;
}

// ─── Static data ──────────────────────────────────────────────────────────────

const EMPLOYEE = {
  name:        "Arjun Mehta",
  id:          "EMP-0042",
  dept:        "Engineering",
  designation: "Senior Software Developer",
  avatar:      "AM",
  manager:     "Rajan Pillai",
  joined:      "14 Mar 2022",
};

const LEAVE_TYPES: LeaveType[] = [
  { key: "casual",    shortLabel: "CL",  label: "Casual Leave",      icon: "ti-beach",         color: "#1e4e8c", bg: "rgba(30,78,140,0.1)",   balance: 8,  total: 12, policy: "Max 3 consecutive days. Apply 1 day in advance.",                   requiresDoc: false },
  { key: "earned",   shortLabel: "EL",  label: "Earned Leave",      icon: "ti-calendar-check", color: "#1b8a6b", bg: "rgba(27,138,107,0.1)",  balance: 14, total: 18, policy: "Min 3 days notice. Carry-forward up to 30 days.",                   requiresDoc: false },
  { key: "sick",     shortLabel: "SL",  label: "Sick Leave",        icon: "ti-stethoscope",    color: "#0e7c86", bg: "rgba(14,124,134,0.1)",  balance: 5,  total: 6,  policy: "Medical certificate required for 3+ consecutive days.",              requiresDoc: true  },
  { key: "lwp",      shortLabel: "LWP", label: "Leave Without Pay", icon: "ti-coin-off",       color: "#b5651d", bg: "rgba(181,101,29,0.1)", balance: 99, total: 99, policy: "Salary deducted. Requires HR approval. No carry-forward.",           requiresDoc: false },
  { key: "maternity",shortLabel: "ML",  label: "Maternity Leave",   icon: "ti-heart",          color: "#ad95cf", bg: "rgba(173,149,207,0.12)", balance: 90, total: 90, policy: "Up to 180 days per Maternity Benefit Act. HR approval required.", requiresDoc: true  },
  { key: "paternity",shortLabel: "PL",  label: "Paternity Leave",   icon: "ti-baby-carriage",  color: "#5b86c9", bg: "rgba(91,134,201,0.1)", balance: 5,  total: 5,  policy: "Within 15 days of child's birth. Birth certificate required.",      requiresDoc: true  },
];

const TEAM_ON_LEAVE = [
  { name: "Priya Sharma", avatar: "PS", type: "EL", from: "Jun 24", to: "Jun 28" },
  { name: "Rahul Singh",  avatar: "RS", type: "CL", from: "Jun 26", to: "Jun 26" },
];

const LEAVE_HISTORY = [
  { type: "Casual Leave",  from: "May 12", to: "May 13", days: 2, status: "approved"  },
  { type: "Sick Leave",    from: "Apr  3", to: "Apr  3", days: 1, status: "approved"  },
  { type: "Earned Leave",  from: "Mar 20", to: "Mar 25", days: 6, status: "rejected"  },
];

const BLANK: LeaveForm = {
  leave_type: "casual", duration: "full_day",
  from_date: "", to_date: "", reason: "",
  contact: "", handover_to: "", handover_notes: "", doc_name: "",
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function calcWorkingDays(from: string, to: string, dur: Duration): number {
  if (!from) return 0;
  if (dur !== "full_day") return 0.5;
  const a = new Date(from + "T12:00:00");
  const b = to ? new Date(to + "T12:00:00") : a;
  if (b < a) return 0;
  let count = 0;
  const cur = new Date(a);
  while (cur <= b) {
    if (cur.getDay() !== 0 && cur.getDay() !== 6) count++;
    cur.setDate(cur.getDate() + 1);
  }
  return count;
}

function calcCalendarDays(from: string, to: string, dur: Duration): number {
  if (!from) return 0;
  if (dur !== "full_day") return 0.5;
  const a = new Date(from + "T12:00:00");
  const b = to ? new Date(to + "T12:00:00") : a;
  if (b < a) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
}

function fmtDate(iso: string): string {
  if (!iso) return "—";
  return new Date(iso + "T12:00:00").toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}

function dayName(iso: string): string {
  if (!iso) return "";
  return new Date(iso + "T12:00:00").toLocaleDateString("en-US", { weekday: "short" });
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function Lbl({ text, required }: { text: string; required?: boolean }) {
  return (
    <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
      {text}{required && <span className="text-red-500 ml-0.5 normal-case">*</span>}
    </label>
  );
}

function Err({ msg }: { msg?: string }) {
  if (!msg) return null;
  return (
    <p className="text-xs text-red-500 mt-1 flex items-center gap-1">
      <i className="ti ti-alert-circle text-xs" /> {msg}
    </p>
  );
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function ApplyLeaveForm({ onCancel }: { onCancel: () => void }) {
  const [form,    setForm]    = useState<LeaveForm>(BLANK);
  const [errors,  setErrors]  = useState<Record<string, string>>({});
  const [submit,  setSubmit]  = useState<SubmitState>("idle");
  const [draftOk, setDraftOk] = useState(false);

  const ltInfo     = LEAVE_TYPES.find(l => l.key === form.leave_type)!;
  const isHalfDay  = form.duration !== "full_day";
  const workDays   = useMemo(() => calcWorkingDays(form.from_date, form.to_date, form.duration), [form.from_date, form.to_date, form.duration]);
  const calDays    = useMemo(() => calcCalendarDays(form.from_date, form.to_date, form.duration), [form.from_date, form.to_date, form.duration]);
  const overLimit  = ltInfo.key !== "lwp" && ltInfo.key !== "maternity" && ltInfo.key !== "paternity" && workDays > ltInfo.balance && workDays > 0;
  const balancePct = ltInfo.key === "lwp" ? 100 : Math.min(100, Math.round((ltInfo.balance / ltInfo.total) * 100));

  const INPUT = "w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm text-gray-800 bg-white outline-none transition focus:border-blue-600 focus:ring-2 focus:ring-blue-100 placeholder:text-gray-400";
  const INPUT_ERR = "w-full border border-red-400 rounded-xl px-3.5 py-2.5 text-sm text-gray-800 bg-red-50 outline-none";

  function setField<K extends keyof LeaveForm>(key: K, val: LeaveForm[K]) {
    setErrors(prev => { const n = { ...prev }; delete n[key]; return n; });
    setForm(prev => ({ ...prev, [key]: val }));
  }

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!form.from_date)                                                e.from_date = "Start date is required.";
    if (!isHalfDay && !form.to_date)                                    e.to_date   = "End date is required.";
    if (!isHalfDay && form.from_date && form.to_date && form.to_date < form.from_date) e.to_date = "End date must be on or after start date.";
    if (!form.reason.trim())                                            e.reason    = "Please provide a reason for your leave.";
    if (form.reason.trim().length < 10)                                 e.reason    = "Reason must be at least 10 characters.";
    if (ltInfo.requiresDoc && !form.doc_name)                          e.doc_name  = "Supporting document is required for this leave type.";
    if (overLimit)                                                      e.from_date = `Only ${ltInfo.balance} working days available for ${ltInfo.label}.`;
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;
    setSubmit("saving");
    setTimeout(() => setSubmit("submitted"), 900);
  }

  function saveDraft() {
    setDraftOk(true);
    setTimeout(() => setDraftOk(false), 2500);
  }

  // ── Success screen ─────────────────────────────────────────────────────────

  if (submit === "submitted") {
    return (
      <div className="min-h-[60vh] flex items-center justify-center p-6">
        <div className="bg-white rounded-3xl border border-gray-200 shadow-lg p-10 text-center w-full max-w-md">
          <div className="relative mb-6 mx-auto w-20 h-20">
            <div className="w-20 h-20 rounded-full bg-green-100 flex items-center justify-center mx-auto animate-pulse">
              <i className="ti ti-circle-check text-4xl text-green-600" />
            </div>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">Request Submitted!</h2>
          <p className="text-sm text-gray-500 mb-1">
            Your <strong className="text-blue-700">{ltInfo.label}</strong> request for{" "}
            <strong className="text-blue-700">{workDays} working day{workDays !== 1 ? "s" : ""}</strong> has been sent for approval.
          </p>
          <p className="text-xs text-gray-400 mb-2">{fmtDate(form.from_date)}{!isHalfDay && form.to_date ? ` → ${fmtDate(form.to_date)}` : ""}</p>
          <div className="my-6 p-4 bg-blue-50 rounded-2xl text-left">
            <p className="text-xs font-semibold text-blue-700 mb-2 uppercase tracking-wide">Approval Chain</p>
            <div className="flex items-center gap-2 flex-wrap">
              {["You","Rajan Pillai","HR Manager"].map((name, i, arr) => (
                <div key={name} className="flex items-center gap-2">
                  <div className="flex items-center gap-1.5">
                    <div className="w-6 h-6 rounded-full bg-blue-200 flex items-center justify-center text-xs font-bold text-blue-700">{name[0]}</div>
                    <span className="text-xs text-blue-800 font-medium">{name}</span>
                  </div>
                  {i < arr.length - 1 && <i className="ti ti-chevron-right text-blue-300 text-xs" />}
                </div>
              ))}
            </div>
          </div>
          <p className="text-xs text-gray-400 mb-8">You will receive an email notification once reviewed. Check the Approvals tab for status updates.</p>
          <div className="flex gap-3 justify-center">
            <button onClick={() => { setForm(BLANK); setSubmit("idle"); }}
              className="px-5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
              Apply Another
            </button>
            <button onClick={onCancel}
              className="px-6 py-2.5 rounded-xl text-sm font-semibold text-white transition-colors"
              style={{ background: "#1e4e8c" }}>
              Back to Dashboard
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── Main form ──────────────────────────────────────────────────────────────

  return (
    <div className="flex flex-col gap-0">

      {/* ── Draft saved toast ─────────────────────────────────────────────── */}
      {draftOk && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 bg-gray-800 text-white text-sm font-medium px-5 py-3 rounded-2xl shadow-xl flex items-center gap-2 animate-pulse">
          <i className="ti ti-device-floppy text-green-400" /> Draft saved successfully
        </div>
      )}

      {/* ── Breadcrumb ────────────────────────────────────────────────────── */}
      <div className="flex items-center gap-2 text-xs text-gray-400 mb-4">
        <button onClick={onCancel} className="hover:text-gray-600 transition-colors">Leave Management</button>
        <i className="ti ti-chevron-right text-gray-300" />
        <span className="text-gray-700 font-medium">Apply for Leave</span>
      </div>

      {/* ── Two-column layout ─────────────────────────────────────────────── */}
      <div className="flex gap-5 items-start">

        {/* ════════════════════════════════════════════════
            LEFT COLUMN — FORM
        ════════════════════════════════════════════════ */}
        <div className="flex-1 min-w-0 flex flex-col gap-4">

          {/* Employee identity banner */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center font-bold text-lg text-white flex-shrink-0"
              style={{ background: "linear-gradient(135deg, #1e4e8c 0%, #5b86c9 100%)" }}>
              {EMPLOYEE.avatar}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-base font-bold text-gray-800">{EMPLOYEE.name}</span>
                <span className="text-xs bg-blue-50 text-blue-700 border border-blue-100 px-2 py-0.5 rounded-full font-mono font-medium">{EMPLOYEE.id}</span>
              </div>
              <div className="text-sm text-gray-500 mt-0.5">{EMPLOYEE.designation} · {EMPLOYEE.dept}</div>
              <div className="text-xs text-gray-400 mt-1 flex items-center gap-3 flex-wrap">
                <span className="flex items-center gap-1"><i className="ti ti-user-check text-xs" /> Reports to: <strong className="text-gray-600">{EMPLOYEE.manager}</strong></span>
                <span className="flex items-center gap-1"><i className="ti ti-calendar text-xs" /> Joined: {EMPLOYEE.joined}</span>
              </div>
            </div>
            <div className="hidden sm:flex items-center gap-1.5 text-xs text-amber-600 bg-amber-50 border border-amber-100 px-3 py-1.5 rounded-xl flex-shrink-0">
              <i className="ti ti-clock text-amber-500" />
              <span className="font-medium">Balance as of today</span>
            </div>
          </div>

          {/* Leave type selector */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
            <Lbl text="Select Leave Type" required />
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mt-1">
              {LEAVE_TYPES.map(lt => {
                const selected = form.leave_type === lt.key;
                const pct = lt.key === "lwp" ? 100 : Math.min(100, Math.round((lt.balance / lt.total) * 100));
                return (
                  <button key={lt.key} onClick={() => setField("leave_type", lt.key)}
                    className={[
                      "relative text-left p-3.5 rounded-xl border-2 transition-all",
                      selected
                        ? "shadow-md"
                        : "border-gray-100 hover:border-gray-200 bg-gray-50 hover:bg-white",
                    ].join(" ")}
                    style={selected ? { borderColor: lt.color, background: lt.bg } : {}}>
                    {selected && (
                      <span className="absolute top-2.5 right-2.5 w-4 h-4 rounded-full flex items-center justify-center" style={{ background: lt.color }}>
                        <i className="ti ti-check text-white" style={{ fontSize: 9 }} />
                      </span>
                    )}
                    <div className="w-8 h-8 rounded-xl flex items-center justify-center mb-2.5 flex-shrink-0" style={{ background: lt.bg }}>
                      <i className={`ti ${lt.icon} text-sm`} style={{ color: lt.color }} />
                    </div>
                    <div className="text-xs font-bold text-gray-800 mb-0.5">{lt.label}</div>
                    {lt.key === "lwp" ? (
                      <div className="text-xs text-gray-400">Unpaid · Unlimited</div>
                    ) : (
                      <>
                        <div className="text-xs font-semibold mb-1.5" style={{ color: lt.color }}>{lt.balance}d left</div>
                        <div className="h-1.5 rounded-full bg-gray-200 overflow-hidden">
                          <div className="h-full rounded-full transition-all" style={{ width: `${pct}%`, background: lt.color }} />
                        </div>
                      </>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Policy note */}
            <div className="mt-3 flex items-start gap-2 text-xs text-gray-500 bg-gray-50 rounded-xl px-3.5 py-2.5 border border-gray-100">
              <i className="ti ti-info-circle mt-0.5 flex-shrink-0" style={{ color: ltInfo.color }} />
              <span>{ltInfo.policy}</span>
            </div>
          </div>

          {/* Duration + dates */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
            <div className="flex flex-col gap-5">

              {/* Duration toggle */}
              <div>
                <Lbl text="Duration" />
                <div className="flex gap-2 flex-wrap">
                  {([
                    { val: "full_day",       icon: "ti-sun",       label: "Full Day"         },
                    { val: "half_morning",   icon: "ti-sun-high",  label: "Half Day · Morning" },
                    { val: "half_afternoon", icon: "ti-sunset-2",  label: "Half Day · Afternoon" },
                  ] as const).map(opt => (
                    <button key={opt.val} onClick={() => {
                      setField("duration", opt.val);
                      if (opt.val !== "full_day") setField("to_date", "");
                    }}
                      className={[
                        "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border-2 transition-all",
                        form.duration === opt.val
                          ? "text-white border-blue-700"
                          : "border-gray-200 text-gray-600 bg-gray-50 hover:bg-white hover:border-gray-300",
                      ].join(" ")}
                      style={form.duration === opt.val ? { background: "#1e4e8c" } : {}}>
                      <i className={`ti ${opt.icon} text-sm`} />
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Date range */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Lbl text="Start Date" required />
                  <div className="relative">
                    <i className="ti ti-calendar absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm pointer-events-none" />
                    <input type="date" value={form.from_date}
                      onChange={e => setField("from_date", e.target.value)}
                      className={[errors.from_date ? INPUT_ERR : INPUT, "pl-9"].join(" ")} />
                  </div>
                  {form.from_date && !errors.from_date && (
                    <p className="text-xs text-gray-400 mt-1 flex items-center gap-1">
                      <i className="ti ti-calendar-event text-xs" /> {dayName(form.from_date)}, {fmtDate(form.from_date)}
                    </p>
                  )}
                  <Err msg={errors.from_date} />
                </div>

                <div>
                  <Lbl text="End Date" required={!isHalfDay} />
                  <div className="relative">
                    <i className="ti ti-calendar absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm pointer-events-none" />
                    <input type="date"
                      value={isHalfDay ? form.from_date : form.to_date}
                      min={form.from_date}
                      disabled={isHalfDay}
                      onChange={e => setField("to_date", e.target.value)}
                      className={[
                        errors.to_date ? INPUT_ERR : INPUT,
                        "pl-9",
                        isHalfDay ? "opacity-40 cursor-not-allowed bg-gray-50" : "",
                      ].join(" ")} />
                  </div>
                  {!isHalfDay && form.to_date && !errors.to_date && (
                    <p className="text-xs text-gray-400 mt-1 flex items-center gap-1">
                      <i className="ti ti-calendar-event text-xs" /> {dayName(form.to_date)}, {fmtDate(form.to_date)}
                    </p>
                  )}
                  <Err msg={errors.to_date} />
                </div>
              </div>

              {/* Working days indicator */}
              {workDays > 0 && (
                <div className={[
                  "flex items-center justify-between gap-3 rounded-xl px-4 py-3 border",
                  overLimit
                    ? "bg-red-50 border-red-200"
                    : "border-blue-100",
                ].join(" ")}
                  style={overLimit ? {} : { background: "rgba(30,78,140,0.05)" }}>
                  <div className="flex items-center gap-2">
                    <i className={`ti ${overLimit ? "ti-alert-triangle text-red-500" : "ti-calendar-check"} text-sm`}
                      style={overLimit ? {} : { color: "#1e4e8c" }} />
                    <div>
                      <span className={`text-sm font-bold ${overLimit ? "text-red-600" : "text-blue-800"}`}>
                        {workDays} working day{workDays !== 1 ? "s" : ""}
                      </span>
                      {calDays > workDays && (
                        <span className="text-xs text-gray-400 ml-2">({calDays} calendar days, excl. weekends)</span>
                      )}
                    </div>
                  </div>
                  {ltInfo.key !== "lwp" && ltInfo.key !== "maternity" && ltInfo.key !== "paternity" && (
                    <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${overLimit ? "bg-red-100 text-red-700" : "bg-blue-100 text-blue-700"}`}>
                      {overLimit ? `Exceeds balance by ${workDays - ltInfo.balance}d` : `${ltInfo.balance - workDays}d will remain`}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Reason + Document */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 flex flex-col gap-5">

            <div>
              <Lbl text="Reason for Leave" required />
              <textarea value={form.reason}
                onChange={e => setField("reason", e.target.value)}
                placeholder="Briefly describe the reason for your leave request…"
                rows={4} maxLength={500}
                className={[errors.reason ? INPUT_ERR : INPUT, "resize-none"].join(" ")} />
              <div className="flex justify-between mt-1">
                <Err msg={errors.reason} />
                <span className={`text-xs ml-auto ${form.reason.length > 450 ? "text-amber-500" : "text-gray-400"}`}>
                  {form.reason.length}/500
                </span>
              </div>
            </div>

            {/* Document upload */}
            <div>
              <div className="flex items-center gap-2 mb-1.5">
                <Lbl text="Supporting Document" />
                {ltInfo.requiresDoc
                  ? <span className="text-xs font-semibold text-red-500 -mt-1.5">(Required)</span>
                  : <span className="text-xs text-gray-400 -mt-1.5">(Optional)</span>
                }
              </div>
              {form.doc_name ? (
                <div className="flex items-center gap-3 p-3.5 bg-green-50 border border-green-200 rounded-xl">
                  <div className="w-8 h-8 rounded-lg bg-green-100 flex items-center justify-center flex-shrink-0">
                    <i className="ti ti-file-check text-green-600 text-sm" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-green-800 truncate">{form.doc_name}</p>
                    <p className="text-xs text-green-600">Attached successfully</p>
                  </div>
                  <button onClick={() => setField("doc_name", "")}
                    className="text-gray-400 hover:text-red-500 transition-colors flex-shrink-0">
                    <i className="ti ti-x" />
                  </button>
                </div>
              ) : (
                <label className={[
                  "flex flex-col items-center justify-center gap-2 border-2 border-dashed rounded-2xl py-7 px-4 cursor-pointer transition-all",
                  errors.doc_name
                    ? "border-red-300 bg-red-50"
                    : "border-gray-200 bg-gray-50 hover:border-blue-400 hover:bg-blue-50",
                ].join(" ")}>
                  <div className="w-10 h-10 rounded-xl bg-white border border-gray-200 flex items-center justify-center shadow-sm">
                    <i className="ti ti-cloud-upload text-gray-400 text-lg" />
                  </div>
                  <div className="text-center">
                    <p className="text-sm font-medium text-gray-700">Click to upload or drag & drop</p>
                    <p className="text-xs text-gray-400 mt-0.5">PDF, JPG, PNG · Max 5 MB</p>
                  </div>
                  <input type="file" accept=".pdf,.jpg,.jpeg,.png" className="hidden"
                    onChange={e => {
                      const file = e.target.files?.[0];
                      if (file) setField("doc_name", file.name);
                    }} />
                </label>
              )}
              <Err msg={errors.doc_name} />
            </div>
          </div>

          {/* Handover details */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 flex flex-col gap-4">
            <div className="flex items-center gap-2 mb-1">
              <i className="ti ti-arrow-forward text-sm" style={{ color: "#1e4e8c" }} />
              <span className="text-sm font-semibold text-gray-700">Handover & Contact</span>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Lbl text="Handover To" />
                <div className="relative">
                  <i className="ti ti-user absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm pointer-events-none" />
                  <input type="text" value={form.handover_to}
                    onChange={e => setField("handover_to", e.target.value)}
                    placeholder="Colleague name"
                    className={[INPUT, "pl-9"].join(" ")} />
                </div>
              </div>
              <div>
                <Lbl text="Emergency Contact" />
                <div className="relative">
                  <i className="ti ti-phone absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm pointer-events-none" />
                  <input type="text" value={form.contact}
                    onChange={e => setField("contact", e.target.value)}
                    placeholder="+91 9876543210"
                    className={[INPUT, "pl-9"].join(" ")} />
                </div>
              </div>
            </div>

            <div>
              <Lbl text="Handover Notes" />
              <textarea value={form.handover_notes}
                onChange={e => setField("handover_notes", e.target.value)}
                placeholder="Pending tasks, important context, instructions for coverage…"
                rows={2} maxLength={300}
                className={[INPUT, "resize-none"].join(" ")} />
            </div>
          </div>

          {/* Footer actions */}
          <div className="flex items-center justify-between gap-3 flex-wrap py-2">
            <button onClick={saveDraft}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
              <i className="ti ti-device-floppy" /> Save Draft
            </button>
            <div className="flex items-center gap-3">
              <button onClick={onCancel}
                className="px-5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button onClick={handleSubmit} disabled={submit === "saving"}
                className="flex items-center gap-2 px-7 py-2.5 rounded-xl text-sm font-semibold text-white transition-all active:scale-95 shadow-md"
                style={{ background: submit === "saving" ? "#7fa3c8" : "#1e4e8c", cursor: submit === "saving" ? "not-allowed" : "pointer" }}>
                {submit === "saving"
                  ? <><i className="ti ti-loader-2 animate-spin" /> Submitting…</>
                  : <><i className="ti ti-send" /> Submit Request</>}
              </button>
            </div>
          </div>

        </div>
        {/* end left column */}

        {/* ════════════════════════════════════════════════
            RIGHT COLUMN — SUMMARY SIDEBAR
        ════════════════════════════════════════════════ */}
        <div className="w-72 flex-shrink-0 flex flex-col gap-4 sticky top-4">

          {/* Live summary */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-2">
              <i className="ti ti-file-description text-sm" style={{ color: "#1e4e8c" }} />
              <span className="text-sm font-bold text-gray-800">Request Summary</span>
            </div>
            <div className="p-4 flex flex-col gap-3">
              {[
                { label: "Employee",   val: EMPLOYEE.name,          icon: "ti-user"        },
                { label: "Leave Type", val: ltInfo.label,           icon: "ti-beach"       },
                { label: "Duration",   val: form.duration === "full_day" ? "Full Day" : form.duration === "half_morning" ? "Half Day (AM)" : "Half Day (PM)", icon: "ti-sun" },
                { label: "From",       val: form.from_date ? `${dayName(form.from_date)}, ${fmtDate(form.from_date)}` : "—", icon: "ti-calendar-event" },
                { label: "To",         val: isHalfDay ? (form.from_date ? fmtDate(form.from_date) : "—") : (form.to_date ? `${dayName(form.to_date)}, ${fmtDate(form.to_date)}` : "—"), icon: "ti-calendar-event" },
                { label: "Working Days", val: workDays > 0 ? `${workDays} day${workDays !== 1 ? "s" : ""}` : "—", icon: "ti-briefcase" },
              ].map(row => (
                <div key={row.label} className="flex items-start gap-2.5">
                  <div className="w-6 h-6 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5" style={{ background: "rgba(30,78,140,0.08)" }}>
                    <i className={`ti ${row.icon} text-xs`} style={{ color: "#1e4e8c" }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs text-gray-400">{row.label}</p>
                    <p className={`text-xs font-semibold mt-0.5 ${row.label === "Working Days" && overLimit ? "text-red-600" : "text-gray-800"}`}>{row.val}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Balance card */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4">
            <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Leave Balance</p>
            <div className="flex items-center gap-2 mb-2.5">
              <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: ltInfo.bg }}>
                <i className={`ti ${ltInfo.icon} text-sm`} style={{ color: ltInfo.color }} />
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-700">{ltInfo.label}</p>
                {ltInfo.key === "lwp"
                  ? <p className="text-xs text-gray-400">Unpaid · No limit</p>
                  : <p className="text-xs text-gray-400">{ltInfo.balance} of {ltInfo.total} days left</p>
                }
              </div>
            </div>
            {ltInfo.key !== "lwp" && (
              <>
                <div className="h-2 rounded-full bg-gray-100 overflow-hidden mb-1.5">
                  <div className="h-full rounded-full transition-all" style={{ width: `${balancePct}%`, background: ltInfo.color }} />
                </div>
                <div className="flex justify-between text-xs text-gray-400">
                  <span>{ltInfo.total - ltInfo.balance} used</span>
                  <span>{ltInfo.balance} remaining</span>
                </div>
              </>
            )}
            {overLimit && (
              <div className="mt-3 flex items-center gap-2 text-xs text-red-600 bg-red-50 px-3 py-2 rounded-xl border border-red-100">
                <i className="ti ti-alert-circle flex-shrink-0" />
                Requested days exceed your balance.
              </div>
            )}
          </div>

          {/* Approval chain */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4">
            <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Approval Chain</p>
            <div className="flex flex-col gap-0">
              {[
                { name: "You",           role: "Requestor",    avatar: "AM", done: true  },
                { name: "Rajan Pillai",  role: "Line Manager", avatar: "RP", done: false },
                { name: "HR Manager",    role: "HR",           avatar: "HR", done: false },
              ].map((step, i, arr) => (
                <div key={step.name} className="flex items-start gap-2.5">
                  <div className="flex flex-col items-center">
                    <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 ${step.done ? "text-white" : "bg-gray-100 text-gray-500"}`}
                      style={step.done ? { background: "#1e4e8c" } : {}}>
                      {step.avatar}
                    </div>
                    {i < arr.length - 1 && <div className="w-px h-5 bg-gray-200 my-0.5" />}
                  </div>
                  <div className="pb-2">
                    <p className="text-xs font-semibold text-gray-700 mt-0.5">{step.name}</p>
                    <p className="text-xs text-gray-400">{step.role}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Team on leave */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4">
            <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">
              Team on Leave
              <span className="ml-2 inline-flex items-center justify-center w-4 h-4 bg-amber-100 text-amber-700 rounded-full text-xs font-bold">{TEAM_ON_LEAVE.length}</span>
            </p>
            {TEAM_ON_LEAVE.length === 0 ? (
              <p className="text-xs text-gray-400">No teammates on leave this period.</p>
            ) : (
              <div className="flex flex-col gap-2.5">
                {TEAM_ON_LEAVE.map(t => (
                  <div key={t.name} className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center text-xs font-bold flex-shrink-0">
                      {t.avatar}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-semibold text-gray-700 truncate">{t.name}</p>
                      <p className="text-xs text-gray-400">{t.from} – {t.to}</p>
                    </div>
                    <span className="text-xs font-semibold bg-blue-50 text-blue-600 px-1.5 py-0.5 rounded flex-shrink-0">{t.type}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* My recent leave history */}
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4">
            <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">My Leave History</p>
            <div className="flex flex-col gap-2.5">
              {LEAVE_HISTORY.map((h, i) => (
                <div key={i} className="flex items-center gap-2.5">
                  <div className={`w-1.5 h-1.5 rounded-full flex-shrink-0 mt-1 ${h.status === "approved" ? "bg-green-500" : "bg-red-400"}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-gray-700 truncate">{h.type}</p>
                    <p className="text-xs text-gray-400">{h.from} · {h.days}d</p>
                  </div>
                  <span className={`text-xs font-semibold px-1.5 py-0.5 rounded-full flex-shrink-0 ${h.status === "approved" ? "bg-green-100 text-green-700" : "bg-red-100 text-red-600"}`}>
                    {h.status === "approved" ? "✓" : "✗"}
                  </span>
                </div>
              ))}
            </div>
          </div>

        </div>
        {/* end right column */}
      </div>
    </div>
  );
}
