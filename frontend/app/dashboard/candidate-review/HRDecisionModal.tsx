"use client";

import { useEffect, useState } from "react";
import { API } from "@/lib/api/endpoints";
import { buildEmailPreview, CompanyInfo, renderTemplateVars } from "@/lib/emailPreview";
import { Candidate, EmailTemplate, RECRUITMENT_API } from "../interview-list/_data";
import clientApi from "@/lib/clientApi";

const AUTO_KEYS = new Set(["FULL_NAME", "FNAME", "LNAME", "EMAIL", "POSITION", "COMPANY"]);

interface Props {
  candidate: Candidate;
  decision:  "approve" | "reject";
  onClose:   () => void;
  onDone:    (updated: Candidate) => void;
}

export function HRDecisionModal({ candidate, decision, onClose, onDone }: Props) {
  const isApprove = decision === "approve";

  const [remarks,          setRemarks]          = useState("");
  const [saving,           setSaving]           = useState(false);
  const [apiError,         setApiError]         = useState("");
  const [templateGroups,   setTemplateGroups]   = useState<{ category: string; templates: EmailTemplate[] }[]>([]);
  const [loadingTemplates, setLoadingTemplates] = useState(false);
  const [selectedTemplate, setSelectedTemplate] = useState<EmailTemplate | null>(null);
  const [extraVars,        setExtraVars]        = useState<Record<string, string>>({});
  const [company,          setCompany]          = useState<CompanyInfo | null>(null);

  // Fetch templates + company info when modal opens for approval
  useEffect(() => {
    if (!isApprove) return;
    setLoadingTemplates(true);
    Promise.all([
      RECRUITMENT_API.emailTemplates(),
      clientApi.get<{ data: CompanyInfo }>(API.settings.company),
    ])
      .then(([tplRes, coRes]) => {
        const grouped: Record<string, EmailTemplate[]> = tplRes.data?.data?.results ?? {} as Record<string, EmailTemplate[]>;
        const groups = Object.entries(grouped)
          .map(([category, items]) => ({
            category,
            templates: items.filter(t => t.is_active),
          }))
          .filter(g => g.templates.length > 0);
        setTemplateGroups(groups);
        const first = groups[0]?.templates[0] ?? null;
        setSelectedTemplate(first);
        setCompany(coRes.data?.data ?? null);
      })
      .catch(() => setApiError("Could not load email templates."))
      .finally(() => setLoadingTemplates(false));
  }, [isApprove]);

  // When template changes, reset manual variable inputs for non-auto variables
  useEffect(() => {
    if (!selectedTemplate) { setExtraVars({}); return; }
    const manual: Record<string, string> = {};
    for (const v of (selectedTemplate.available_variables ?? [])) {
      if (!AUTO_KEYS.has(v)) manual[v] = "";
    }
    setExtraVars(manual);
  }, [selectedTemplate]);

  function previewVars(): Record<string, string> {
    const parts = candidate.name.trim().split(/\s+/);
    return {
      FULL_NAME: candidate.name,
      FNAME:     parts[0] ?? candidate.name,
      LNAME:     parts.length > 1 ? parts[parts.length - 1] : "",
      EMAIL:     candidate.email,
      POSITION:  candidate.position_applied,
      COMPANY:   company?.company_name ?? "[Company]",
      ...extraVars,
    };
  }

  function previewHtml(): string {
    if (!selectedTemplate) return "";
    const body = renderTemplateVars(selectedTemplate.body, previewVars());
    return buildEmailPreview(body, company);
  }

  async function handleConfirm() {
    setSaving(true);
    setApiError("");
    try {
      const body: {
        decision:       "approve" | "reject";
        remarks?:       string;
        template_name?: string;
        extra_context?: Record<string, string>;
      } = { decision, remarks };

      if (isApprove && selectedTemplate) {
        body.template_name = selectedTemplate.name;
        body.extra_context = extraVars;
      }

      const res = await RECRUITMENT_API.hrDecision(candidate.id, body);
      onDone(res.data.data);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setApiError(msg || "Action failed.");
    } finally {
      setSaving(false);
    }
  }

  const hasUnfilledVars = Object.values(extraVars).some(v => !v.trim());

  return (
    <div className="modal-overlay open" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: isApprove ? 700 : 480 }}>
        <div className="modal-header">
          <div className="modal-title">
            {isApprove ? "Approve & Onboard" : "Request Revision"} — {candidate.name}
          </div>
          <button className="modal-close" onClick={onClose}><i className="ti ti-x" /></button>
        </div>

        <div className="modal-body">
          {apiError && (
            <div className="alert alert-error mb-16">
              <i className="ti ti-alert-circle" /><div>{apiError}</div>
            </div>
          )}

          {/* ── Approve: template selection + preview ── */}
          {isApprove && (
            <>
              <div className="field-group mb-16">
                <label className="field-label">Email Template *</label>
                {loadingTemplates ? (
                  <div className="text-sm text-[var(--on-variant)]">
                    <i className="ti ti-loader-2 spin" /> Loading templates…
                  </div>
                ) : (
                  <select
                    className="field-input field-select"
                    value={selectedTemplate?.name ?? ""}
                    onChange={e => {
                      const found = templateGroups
                        .flatMap(g => g.templates)
                        .find(t => t.name === e.target.value) ?? null;
                      setSelectedTemplate(found);
                    }}
                  >
                    {templateGroups.length === 0 && (
                      <option value="">No active templates — create one in Settings → Email Templates</option>
                    )}
                    {templateGroups.map(g => (
                      <optgroup
                        key={g.category}
                        label={g.category.charAt(0).toUpperCase() + g.category.slice(1)}
                      >
                        {g.templates.map(t => (
                          <option key={t.name} value={t.name}>{t.display_name}</option>
                        ))}
                      </optgroup>
                    ))}
                  </select>
                )}
              </div>

              {/* Manual inputs for non-auto variables */}
              {Object.keys(extraVars).length > 0 && (
                <div className="settings-card mb-16">
                  <div className="settings-card-title mb-8">Fill in template variables</div>
                  <div className="form-row cols-2">
                    {Object.keys(extraVars).map(key => (
                      <div key={key} className="field-group">
                        <label className="field-label">
                          {key.replace(/_/g, " ")} <span className="text-[var(--error)]">*</span>
                        </label>
                        <input
                          className="field-input"
                          placeholder={`Enter ${key.replace(/_/g, " ")}`}
                          value={extraVars[key]}
                          onChange={e => setExtraVars(prev => ({ ...prev, [key]: e.target.value }))}
                        />
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Full email preview with company branding */}
              {selectedTemplate && (
                <div className="settings-card mb-16">
                  <div className="settings-card-title mb-8">
                    <i className="ti ti-mail" /> Email Preview
                  </div>
                  <div style={{ fontSize: 12, color: "var(--on-variant)", marginBottom: 2 }}>
                    <strong>To:</strong> {candidate.email}
                  </div>
                  <div style={{ fontSize: 12, color: "var(--on-variant)", marginBottom: 10 }}>
                    <strong>Subject:</strong>{" "}
                    {renderTemplateVars(selectedTemplate.subject, previewVars())}
                  </div>
                  <iframe
                    srcDoc={previewHtml()}
                    sandbox="allow-same-origin"
                    style={{
                      width: "100%",
                      height: 340,
                      border: "1px solid var(--outline-v)",
                      borderRadius: 6,
                      display: "block",
                    }}
                    title="Email body preview"
                  />
                </div>
              )}
            </>
          )}

          {/* ── Reject: simple confirmation ── */}
          {!isApprove && (
            <div className="alert alert-warn mb-16">
              <i className="ti ti-alert-triangle" />
              <div>
                A revision request will be sent to <strong>{candidate.name}</strong> to resubmit
                their details.
              </div>
            </div>
          )}

          {/* Remarks */}
          <div className="field-group">
            <label className="field-label">
              {isApprove ? "HR Remarks (optional)" : "Revision notes (required)"}
            </label>
            <input
              className="field-input"
              placeholder={isApprove ? "Any onboarding notes…" : "Specify what needs to be corrected…"}
              value={remarks}
              onChange={e => setRemarks(e.target.value)}
            />
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button
            className={`btn ${isApprove ? "btn-success" : "btn-danger"}`}
            onClick={handleConfirm}
            disabled={
              saving ||
              (!isApprove && !remarks.trim()) ||
              (isApprove && (!selectedTemplate || hasUnfilledVars))
            }
          >
            {saving ? (
              <><i className="ti ti-loader-2 spin" /> Processing…</>
            ) : isApprove ? (
              <><i className="ti ti-check" /> Approve & Send Email</>
            ) : (
              <><i className="ti ti-alert-triangle" /> Request Revision</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
