"use client";

import { useEffect, useRef, useState } from "react";

const BRANCHES = ["Head Office", "Mumbai", "Chennai", "Hyderabad", "Bengaluru", "Delhi"];

interface Props {
  selected: string[];
  onChange: (branches: string[]) => void;
}

export default function BranchDropdown({ selected, onChange }: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handle(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", handle);
    return () => document.removeEventListener("mousedown", handle);
  }, []);

  function toggle(branch: string) {
    onChange(selected.includes(branch) ? selected.filter(b => b !== branch) : [...selected, branch]);
  }

  const label = selected.length === 0 ? "All Branches" :
    selected.length === 1 ? selected[0] : `${selected.length} Branches`;

  const isActive = open || selected.length > 0;

  return (
    <div ref={ref} style={{ position: "relative" }}>
      <button
        onClick={() => setOpen(o => !o)}
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "7px 14px",
          borderRadius: "var(--radius)",
          border: `1.5px solid ${isActive ? "var(--primary)" : "var(--outline-v)"}`,
          background: "#fff",
          color: isActive ? "var(--primary)" : "var(--on-variant)",
          fontSize: 13,
          fontWeight: 500,
          cursor: "pointer",
          boxShadow: isActive ? "0 0 0 3px rgba(30,78,140,0.1)" : "none",
          transition: "all 0.15s",
          whiteSpace: "nowrap",
          fontFamily: "inherit",
        }}
      >
        <i className="ti ti-building" style={{ fontSize: 15 }} />
        {label}
        {selected.length > 0 && (
          <span style={{
            width: 20, height: 20, borderRadius: "50%",
            background: "var(--primary)", color: "#fff",
            fontSize: 11, fontWeight: 700,
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            flexShrink: 0,
          }}>
            {selected.length}
          </span>
        )}
        <i className="ti ti-chevron-down" style={{
          fontSize: 12, flexShrink: 0,
          transform: open ? "rotate(180deg)" : "none",
          transition: "transform 0.15s",
        }} />
      </button>

      {open && (
        <div style={{
          position: "absolute",
          left: 0,
          top: "calc(100% + 6px)",
          zIndex: 50,
          background: "#fff",
          border: "1px solid var(--outline-v)",
          borderRadius: "var(--radius-lg)",
          boxShadow: "var(--shadow-md)",
          overflow: "hidden",
          minWidth: 220,
        }}>
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "space-between",
            padding: "10px 14px",
            borderBottom: "1px solid var(--outline-v)",
          }}>
            <span style={{ fontSize: 11, fontWeight: 700, color: "var(--on-variant)", textTransform: "uppercase", letterSpacing: "0.04em" }}>
              Filter by Branch
            </span>
            {selected.length > 0 && (
              <button
                onClick={() => onChange([])}
                style={{ background: "none", border: "none", color: "var(--error)", fontSize: 12, fontWeight: 500, cursor: "pointer", display: "flex", alignItems: "center", gap: 3, fontFamily: "inherit" }}
              >
                <i className="ti ti-x" style={{ fontSize: 11 }} /> Clear
              </button>
            )}
          </div>

          <div>
            {BRANCHES.map(branch => {
              const checked = selected.includes(branch);
              return (
                <label
                  key={branch}
                  style={{
                    display: "flex", alignItems: "center", gap: 10,
                    padding: "9px 14px",
                    cursor: "pointer",
                    background: checked ? "rgba(30,78,140,0.06)" : "transparent",
                    color: checked ? "var(--primary)" : "var(--on-bg)",
                    fontSize: 13,
                    fontWeight: checked ? 600 : 400,
                    userSelect: "none",
                    transition: "background 0.12s",
                  }}
                >
                  <div style={{
                    width: 16, height: 16, borderRadius: 4, flexShrink: 0,
                    border: checked ? "none" : "1.5px solid var(--outline-v)",
                    background: checked ? "var(--primary)" : "#fff",
                    display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    {checked && <i className="ti ti-check" style={{ fontSize: 10, color: "#fff" }} />}
                  </div>
                  <input type="checkbox" checked={checked} onChange={() => toggle(branch)} style={{ display: "none" }} />
                  {branch}
                </label>
              );
            })}
          </div>

          <div style={{ padding: "10px 14px", borderTop: "1px solid var(--outline-v)" }}>
            <button
              onClick={() => setOpen(false)}
              className="btn btn-filled"
              style={{ width: "100%", justifyContent: "center", fontSize: 12 }}
            >
              {selected.length === 0 ? "Show All Branches" : `Apply (${selected.length} selected)`}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
