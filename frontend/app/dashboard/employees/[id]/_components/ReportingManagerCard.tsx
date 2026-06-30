"use client";

import { useState } from "react";
import { API } from "@/lib/api/endpoints";
import { useFetch } from "@/hooks/useFetch";
import { getStoredUser } from "@/lib/auth";
import clientApi from "@/lib/clientApi";

interface EmployeeResult {
  uuid:        string;
  full_name:   string;
  employee_id: string;
  department:  string;
  designation: string;
}

interface ListResponse {
  results: EmployeeResult[];
}

interface Props {
  employeeCode:       string;
  currentManagerId:   string | null;
  currentManagerName: string | null;
  onUpdated: (id: string | null, name: string | null) => void;
}

export function ReportingManagerCard({ employeeCode, currentManagerId, currentManagerName, onUpdated }: Props) {
  const [editing,  setEditing]  = useState(false);
  const [search,   setSearch]   = useState("");
  const [selected, setSelected] = useState<EmployeeResult | null>(null);
  const [saving,   setSaving]   = useState(false);
  const [apiError, setApiError] = useState("");

  const currentUser = getStoredUser();
  const canEdit = currentUser?.role === "hr_admin" || currentUser?.role === "system_admin";

  const searchUrl =
    editing && search.trim().length >= 2
      ? `${API.employees.list}?search=${encodeURIComponent(search.trim())}&page_size=8&is_active=true`
      : null;

  const { data: searchData, loading: searching } = useFetch<ListResponse>(searchUrl);
  const results = searchData?.results ?? [];

  async function handleSave() {
    setSaving(true);
    setApiError("");
    try {
      await clientApi.patch(API.employees.reportingManager(employeeCode), {
        reporting_manager_id: selected ? selected.uuid : null,
      });
      onUpdated(selected?.uuid ?? null, selected?.full_name ?? null);
      closeEditor();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setApiError(msg || "Failed to update reporting manager.");
    } finally {
      setSaving(false);
    }
  }

  function handleClear() {
    setSaving(true);
    setApiError("");
    clientApi
      .patch(API.employees.reportingManager(employeeCode), { reporting_manager_id: null })
      .then(() => { onUpdated(null, null); closeEditor(); })
      .catch((err: unknown) => {
        const msg = (err as { response?: { data?: { message?: string } } })?.response?.data?.message;
        setApiError(msg || "Failed to clear reporting manager.");
      })
      .finally(() => setSaving(false));
  }

  function closeEditor() {
    setEditing(false);
    setSearch("");
    setSelected(null);
    setApiError("");
  }

  return (
    <div className="settings-card mb-16">
      <div className="settings-card-title" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
        <span><i className="ti ti-user-check" style={{ marginRight: 6 }} />Reporting Manager</span>
        {canEdit && !editing && (
          <button className="btn btn-ghost" style={{ padding: "4px 12px", fontSize: 12 }} onClick={() => setEditing(true)}>
            <i className="ti ti-edit" /> Change
          </button>
        )}
      </div>

      {!editing ? (
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {currentManagerName ? (
            <>
              <div style={{
                width: 36, height: 36, borderRadius: "50%",
                background: "var(--primary)", color: "#fff",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 13, fontWeight: 600, flexShrink: 0,
              }}>
                {currentManagerName.split(" ").map((w: string) => w[0]).join("").toUpperCase().slice(0, 2)}
              </div>
              <span style={{ fontSize: 14, fontWeight: 500, color: "var(--on-bg)" }}>{currentManagerName}</span>
            </>
          ) : (
            <span style={{ fontSize: 13, color: "var(--on-variant)" }}>
              <i className="ti ti-user-x" style={{ marginRight: 4 }} />
              No reporting manager assigned
            </span>
          )}
        </div>
      ) : (
        <div>
          {apiError && (
            <div className="alert alert-error mb-12" style={{ padding: "8px 12px", fontSize: 13 }}>
              <i className="ti ti-alert-circle" /> {apiError}
            </div>
          )}

          {selected ? (
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
              <div style={{
                width: 36, height: 36, borderRadius: "50%",
                background: "var(--primary)", color: "#fff",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 13, fontWeight: 600, flexShrink: 0,
              }}>
                {selected.full_name.split(" ").map((w: string) => w[0]).join("").toUpperCase().slice(0, 2)}
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 500 }}>{selected.full_name}</div>
                <div style={{ fontSize: 12, color: "var(--on-variant)" }}>{selected.employee_id} · {selected.department}</div>
              </div>
              <button className="btn btn-ghost" style={{ marginLeft: "auto", padding: "4px 10px", fontSize: 12 }} onClick={() => setSelected(null)}>
                <i className="ti ti-x" /> Clear
              </button>
            </div>
          ) : (
            <div style={{ position: "relative", marginBottom: 12 }}>
              <input
                className="field-input"
                placeholder="Search employee by name or ID…"
                value={search}
                onChange={e => setSearch(e.target.value)}
                autoFocus
              />
              {searching && (
                <div style={{ position: "absolute", right: 10, top: "50%", transform: "translateY(-50%)" }}>
                  <i className="ti ti-loader-2 spin" style={{ color: "var(--on-variant)" }} />
                </div>
              )}
              {results.length > 0 && (
                <div style={{
                  position: "absolute", top: "calc(100% + 4px)", left: 0, right: 0, zIndex: 50,
                  background: "#fff", border: "1px solid var(--outline-v)", borderRadius: 8,
                  boxShadow: "0 4px 16px rgba(0,0,0,0.10)", overflow: "hidden",
                }}>
                  {results.map(emp => (
                    <button
                      key={emp.uuid}
                      style={{
                        display: "flex", alignItems: "center", gap: 10,
                        width: "100%", padding: "10px 14px", background: "none",
                        border: "none", cursor: "pointer", textAlign: "left",
                        borderBottom: "1px solid var(--outline-v)",
                      }}
                      onClick={() => { setSelected(emp); setSearch(""); }}
                      onMouseEnter={e => (e.currentTarget.style.background = "var(--bg-mid)")}
                      onMouseLeave={e => (e.currentTarget.style.background = "none")}
                    >
                      <div style={{
                        width: 30, height: 30, borderRadius: "50%",
                        background: "var(--primary)", color: "#fff",
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontSize: 11, fontWeight: 600, flexShrink: 0,
                      }}>
                        {emp.full_name.split(" ").map((w: string) => w[0]).join("").toUpperCase().slice(0, 2)}
                      </div>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 500, color: "var(--on-bg)" }}>{emp.full_name}</div>
                        <div style={{ fontSize: 11, color: "var(--on-variant)" }}>{emp.employee_id} · {emp.department}</div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
              {search.trim().length >= 2 && !searching && results.length === 0 && (
                <div style={{
                  position: "absolute", top: "calc(100% + 4px)", left: 0, right: 0, zIndex: 50,
                  background: "#fff", border: "1px solid var(--outline-v)", borderRadius: 8,
                  padding: "12px 14px", fontSize: 13, color: "var(--on-variant)",
                  boxShadow: "0 4px 16px rgba(0,0,0,0.10)",
                }}>
                  No employees found.
                </div>
              )}
            </div>
          )}

          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <button
              className="btn btn-primary"
              style={{ padding: "6px 16px", fontSize: 13 }}
              onClick={handleSave}
              disabled={saving || !selected}
            >
              {saving ? <><i className="ti ti-loader-2 spin" /> Saving…</> : "Save"}
            </button>
            {currentManagerId && (
              <button
                className="btn btn-ghost"
                style={{ padding: "6px 14px", fontSize: 13, color: "var(--error)" }}
                onClick={handleClear}
                disabled={saving}
              >
                Remove
              </button>
            )}
            <button className="btn btn-ghost" style={{ padding: "6px 14px", fontSize: 13 }} onClick={closeEditor} disabled={saving}>
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
