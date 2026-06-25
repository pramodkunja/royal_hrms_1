"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import {
  getEmployee,
  updateEmployee,
  PROFILE_SECTIONS,
  PROFILE_TABS,
  type DetailValues,
  type TableRow,
} from "../_data";
import ProfileHeader from "./_components/ProfileHeader";
import ProfileTabBar from "./_components/ProfileTabBar";
import ProfileSidebar from "./_components/ProfileSidebar";
import ProfileForm from "./_components/ProfileForm";

export default function EmployeeProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const [tab, setTab] = useState<string>("profile");
  const [sectionId, setSectionId] = useState<string>("basic");
  // incremented on each save so useMemo re-reads the mutated MOCK_EMPLOYEES
  const [saveCount, setSaveCount] = useState(0);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const employee = useMemo(() => getEmployee(id), [id, saveCount]);

  // form state seeded once from the employee record
  const [values, setValues] = useState<DetailValues>(() => ({ ...(employee?.details ?? {}) }));
  const [tables, setTables] = useState<Record<string, TableRow[]>>(() =>
    employee ? JSON.parse(JSON.stringify(employee.tables)) : {},
  );
  // baseline used for dirty-check + cancel
  const [baseValues, setBaseValues] = useState(values);
  const [baseTables, setBaseTables] = useState(tables);
  const [justSaved, setJustSaved] = useState(false);

  const section = PROFILE_SECTIONS.find(s => s.id === sectionId)!;

  const dirty =
    JSON.stringify(values) !== JSON.stringify(baseValues) ||
    JSON.stringify(tables) !== JSON.stringify(baseTables);

  // ── employee not found ──
  if (!employee) {
    return (
      <div className="bg-white rounded-xl border border-[var(--outline-v)] p-12 text-center max-w-lg mx-auto mt-10">
        <i className="ti ti-user-question text-5xl text-[var(--outline)] block mb-4" />
        <h2 className="text-[17px] font-semibold text-[var(--on-bg)] mb-1.5">Employee not found</h2>
        <p className="text-[13px] text-[var(--on-variant)] mb-5">
          No employee exists with code <span className="font-semibold">{id}</span>.
        </p>
        <Link
          href="/dashboard/employees"
          className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-lg text-[13px] font-semibold bg-[var(--primary)] text-white hover:bg-[#163d72] transition-colors"
        >
          <i className="ti ti-arrow-left text-[15px]" />
          Back to Employees
        </Link>
      </div>
    );
  }

  function onFieldChange(key: string, val: string) {
    setValues(v => ({ ...v, [key]: val }));
    setJustSaved(false);
  }
  function onRowsChange(rows: TableRow[]) {
    setTables(t => ({ ...t, [sectionId]: rows }));
    setJustSaved(false);
  }
  function onSave() {
    // Write changes back into MOCK_EMPLOYEES so they survive navigation.
    // Replace this with PUT /api/employees/{id}/ when the backend is ready.
    updateEmployee(id, values, tables);
    setBaseValues(values);
    setBaseTables(tables);
    setSaveCount(c => c + 1); // triggers employee re-read → ProfileHeader refreshes
    setJustSaved(true);
  }
  function onCancel() {
    setValues(baseValues);
    setTables(baseTables);
    setJustSaved(false);
  }

  const activeTab = PROFILE_TABS.find(t => t.id === tab)!;

  return (
    <div>
      <ProfileHeader employee={employee} />
      <ProfileTabBar active={tab} onChange={setTab} />

      {justSaved && (
        <div className="flex items-center gap-2 px-4 py-2.5 mb-4 rounded-lg bg-[var(--success-c)] text-[var(--success)] text-[13px] font-medium">
          <i className="ti ti-circle-check text-[16px]" />
          Changes saved successfully.
        </div>
      )}

      {tab === "profile" ? (
        <div style={{ display: "flex", gap: "1rem", alignItems: "flex-start" }}>
          <div style={{ width: "220px", flexShrink: 0 }}>
            <ProfileSidebar active={sectionId} onChange={setSectionId} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
          <ProfileForm
            section={section}
            values={values}
            rows={tables[sectionId] ?? []}
            dirty={dirty}
            onFieldChange={onFieldChange}
            onRowsChange={onRowsChange}
            onSave={onSave}
            onCancel={onCancel}
          />
          </div>
        </div>
      ) : (
        <TabPlaceholder icon={activeTab.icon} label={activeTab.label} />
      )}
    </div>
  );
}

function TabPlaceholder({ icon, label }: { icon: string; label: string }) {
  return (
    <div className="bg-white rounded-xl border border-[var(--outline-v)] p-14 text-center">
      <div className="w-14 h-14 rounded-2xl bg-[var(--bg-mid)] flex items-center justify-center mx-auto mb-4">
        <i className={`ti ${icon} text-[26px] text-[var(--primary)]`} />
      </div>
      <h3 className="text-[16px] font-semibold text-[var(--on-bg)] mb-1.5">{label}</h3>
      <p className="text-[13px] text-[var(--on-variant)] max-w-sm mx-auto">
        The {label} module will appear here. This tab is wired and ready for its content.
      </p>
    </div>
  );
}
