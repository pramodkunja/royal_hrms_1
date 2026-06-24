"use client";

import { useEffect, useRef, useState } from "react";
import {
  validateTemplateForm, EMPTY_TEMPLATE_FORM, toSlug,
  ATTACHMENT_ACCEPT_ATTR, fileKind, FILE_KIND_META, formatBytes,
  type ApiEmailTemplate, type TemplateForm, type TemplateFormErrors,
} from "../_data";

interface Props {
  template: ApiEmailTemplate | null;   // null = add mode
  saving:   boolean;
  onClose:  () => void;
  onSave:   (form: TemplateForm) => Promise<void>;
}

const TOOLBAR = [
  { cmd: "bold",                icon: "ti-bold",             tip: "Bold"          },
  { cmd: "italic",              icon: "ti-italic",           tip: "Italic"        },
  { cmd: "underline",           icon: "ti-underline",        tip: "Underline"     },
  { cmd: "strikeThrough",       icon: "ti-strikethrough",    tip: "Strikethrough" },
  { cmd: "|" },
  { cmd: "insertUnorderedList", icon: "ti-list",             tip: "Bullet list"   },
  { cmd: "insertOrderedList",   icon: "ti-list-numbers",     tip: "Numbered list" },
  { cmd: "|" },
  { cmd: "justifyLeft",         icon: "ti-align-left",       tip: "Align left"    },
  { cmd: "justifyCenter",       icon: "ti-align-center",     tip: "Align center"  },
  { cmd: "justifyRight",        icon: "ti-align-right",      tip: "Align right"   },
  { cmd: "|" },
  { cmd: "createLink",          icon: "ti-link",             tip: "Insert link"   },
  { cmd: "unlink",              icon: "ti-unlink",           tip: "Remove link"   },
  { cmd: "|" },
  { cmd: "removeFormat",        icon: "ti-clear-formatting", tip: "Clear format"  },
];

export default function EditTemplateModal({ template, saving, onClose, onSave }: Props) {
  const isAddMode = template === null;

  const [form,       setForm]       = useState<TemplateForm>(
    isAddMode
      ? { ...EMPTY_TEMPLATE_FORM }
      : { name: template.name, display_name: template.display_name, subject: template.subject, body: template.body, attachments: [] }
  );
  const [slugEdited, setSlugEdited] = useState(false);  // true once user manually edits the slug
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [errors,     setErrors]     = useState<TemplateFormErrors>({});
  const [viewSource, setViewSource] = useState(false);

  const editorRef = useRef<HTMLDivElement>(null);

  // Seed the editor when switching back from source view
  useEffect(() => {
    if (!viewSource && editorRef.current) {
      editorRef.current.innerHTML = form.body;
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [viewSource]);

  // Seed on first mount
  useEffect(() => {
    if (editorRef.current) editorRef.current.innerHTML = form.body;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function syncBody() {
    if (editorRef.current) setForm(p => ({ ...p, body: editorRef.current!.innerHTML }));
  }

  function execCmd(cmd: string) {
    if (cmd === "createLink") {
      const url = window.prompt("Enter URL:");
      if (url) document.execCommand("createLink", false, url);
    } else {
      document.execCommand(cmd, false);
    }
    syncBody();
    editorRef.current?.focus();
  }

  function insertTag(tag: string) {
    if (viewSource) {
      setForm(p => ({ ...p, body: p.body + tag }));
      return;
    }
    editorRef.current?.focus();
    document.execCommand("insertText", false, tag);
    syncBody();
  }

  function addFiles(files: FileList | null) {
    if (!files) return;
    const incoming = Array.from(files);
    setForm(p => ({
      ...p,
      attachments: [
        ...p.attachments,
        ...incoming.filter(f => !p.attachments.some(a => a.name === f.name && a.size === f.size)),
      ],
    }));
  }

  function removeFile(index: number) {
    setForm(p => ({ ...p, attachments: p.attachments.filter((_, i) => i !== index) }));
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragOver(false);
    addFiles(e.dataTransfer.files);
  }

  async function handleSave() {
    syncBody();
    const latestBody = editorRef.current?.innerHTML ?? form.body;
    const latest: TemplateForm = { ...form, body: latestBody };
    const errs = validateTemplateForm(latest, isAddMode);
    if (Object.keys(errs).length) { setErrors(errs); return; }
    await onSave(latest);
  }

  // Build tag list: use available_variables from the template, or empty in add mode
  const variables: string[] = !isAddMode && template.available_variables?.length
    ? template.available_variables
    : [];

  return (
    <div className="modal-overlay open" onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="modal" style={{ width: "min(980px, 96vw)", maxHeight: "92vh", overflow: "hidden", display: "flex", flexDirection: "column" }}>

        {/* ── Header ── */}
        <div className="modal-header" style={{ flexShrink: 0 }}>
          <div style={{ minWidth: 0 }}>
            <div className="modal-title">
              {isAddMode
                ? "Add Email Template"
                : <>Edit — <span style={{ color: "var(--primary)" }}>{template.display_name}</span></>
              }
            </div>
            <div style={{ fontSize: 12, color: "var(--on-variant)", marginTop: 2 }}>
              {isAddMode
                ? "Fill in the subject and body for the new template"
                : template.description
              }
            </div>
          </div>
          <button className="modal-close" onClick={onClose} aria-label="Close" suppressHydrationWarning>
            <i className="ti ti-x" />
          </button>
        </div>

        {/* ── Editor + sidebar ── */}
        <div style={{ display: "grid", gridTemplateColumns: "1fr 200px", flex: 1, minHeight: 0, overflow: "hidden" }}>

          {/* Left: fields + editor */}
          <div style={{ display: "flex", flexDirection: "column", overflow: "hidden", borderRight: "1px solid var(--outline-v)" }}>
            <div style={{ flex: 1, overflowY: "auto", padding: "16px 20px", display: "flex", flexDirection: "column", gap: 14 }}>

              {/* Display Name + slug — add mode only */}
              {isAddMode && (
                <>
                  <div className="field-group">
                    <label className="field-label">Display Name <span style={{ color: "var(--error)" }}>*</span></label>
                    <input className="field-input" placeholder="e.g. Pay Slip, Birthday Wish"
                      value={form.display_name}
                      onChange={e => {
                        const val = e.target.value;
                        setForm(p => ({
                          ...p,
                          display_name: val,
                          name: slugEdited ? p.name : toSlug(val),
                        }));
                        setErrors(p => ({ ...p, display_name: undefined }));
                      }}
                      suppressHydrationWarning />
                    {errors.display_name && <span className="field-error">{errors.display_name}</span>}
                  </div>

                  <div className="field-group">
                    <label className="field-label" style={{ display: "flex", alignItems: "center", gap: 6 }}>
                      Slug (name) <span style={{ color: "var(--error)" }}>*</span>
                      <span style={{ fontSize: 10, color: "var(--outline)", fontWeight: 400 }}>auto-generated · lowercase_with_underscores</span>
                    </label>
                    <input className="field-input" placeholder="e.g. pay_slip"
                      value={form.name}
                      onChange={e => {
                        setSlugEdited(true);
                        setForm(p => ({ ...p, name: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "") }));
                        setErrors(p => ({ ...p, name: undefined }));
                      }}
                      style={{ fontFamily: "ui-monospace, monospace", fontSize: 12 }}
                      suppressHydrationWarning />
                    {errors.name && <span className="field-error">{errors.name}</span>}
                  </div>
                </>
              )}

              {/* Subject */}
              <div className="field-group">
                <label className="field-label">Subject <span style={{ color: "var(--error)" }}>*</span></label>
                <input className="field-input" placeholder="Email subject line…"
                  value={form.subject}
                  onChange={e => { setForm(p => ({ ...p, subject: e.target.value })); setErrors(p => ({ ...p, subject: undefined })); }}
                  suppressHydrationWarning />
                {errors.subject && <span className="field-error">{errors.subject}</span>}
              </div>

              {/* Body */}
              <div className="field-group" style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 4 }}>
                  <label className="field-label" style={{ marginBottom: 0 }}>
                    Body <span style={{ color: "var(--error)" }}>*</span>
                  </label>
                  <button type="button" suppressHydrationWarning
                    onClick={() => { syncBody(); setViewSource(v => !v); }}
                    style={{ fontSize: 11, color: "var(--primary)", background: "none", border: "none", cursor: "pointer", fontFamily: "inherit", display: "flex", alignItems: "center", gap: 4 }}>
                    <i className={`ti ${viewSource ? "ti-eye" : "ti-code"}`} style={{ fontSize: 13 }} />
                    {viewSource ? "Visual" : "HTML source"}
                  </button>
                </div>

                {/* Toolbar */}
                {!viewSource && (
                  <div style={{ display: "flex", alignItems: "center", gap: 2, flexWrap: "wrap", padding: "5px 8px", border: "1.5px solid var(--outline-v)", borderBottom: "none", borderRadius: "var(--radius) var(--radius) 0 0", background: "var(--bg-low)" }}>
                    {TOOLBAR.map((btn, i) =>
                      btn.cmd === "|" ? (
                        <div key={i} style={{ width: 1, height: 16, background: "var(--outline-v)", margin: "0 3px" }} />
                      ) : (
                        <button key={btn.cmd} type="button" title={btn.tip} suppressHydrationWarning
                          onMouseDown={e => { e.preventDefault(); execCmd(btn.cmd!); }}
                          style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", background: "none", border: "none", borderRadius: 4, cursor: "pointer", color: "var(--on-variant)", fontSize: 14 }}
                          onMouseEnter={e => (e.currentTarget.style.background = "var(--bg-mid)")}
                          onMouseLeave={e => (e.currentTarget.style.background = "none")}>
                          <i className={`ti ${btn.icon}`} />
                        </button>
                      )
                    )}
                  </div>
                )}

                {/* Visual editor */}
                {!viewSource && (
                  <div ref={editorRef} contentEditable suppressContentEditableWarning
                    onInput={syncBody} onBlur={syncBody}
                    style={{ flex: 1, minHeight: 200, padding: "12px 14px", border: "1.5px solid var(--outline-v)", borderRadius: "0 0 var(--radius) var(--radius)", outline: "none", overflowY: "auto", fontSize: 13, lineHeight: 1.7, color: "var(--on-bg)", background: "#fff", fontFamily: "inherit" }}
                  />
                )}

                {/* HTML source */}
                {viewSource && (
                  <textarea value={form.body} suppressHydrationWarning
                    onChange={e => setForm(p => ({ ...p, body: e.target.value }))}
                    style={{ flex: 1, minHeight: 200, resize: "vertical", padding: "12px 14px", border: "1.5px solid var(--outline-v)", borderRadius: "var(--radius)", fontFamily: "ui-monospace, monospace", fontSize: 12, lineHeight: 1.7, outline: "none", color: "var(--on-bg)" }}
                    onFocus={e => (e.currentTarget.style.borderColor = "var(--primary)")}
                    onBlur={e => (e.currentTarget.style.borderColor = "var(--outline-v)")}
                  />
                )}

                {errors.body && <span className="field-error">{errors.body}</span>}
              </div>

              <div style={{ height: 4, flexShrink: 0 }} />
            </div>
          </div>

          {/* Right: variable tags sidebar */}
          <div style={{ overflowY: "auto", background: "var(--bg-low)" }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: "var(--outline)", letterSpacing: "0.08em", textTransform: "uppercase", padding: "14px 14px 10px" }}>
              {isAddMode ? "Common Tags" : "Available Tags"}
            </div>

            {variables.length > 0 ? (
              <div style={{ padding: "0 10px 14px", display: "flex", flexDirection: "column", gap: 4 }}>
                {variables.map(v => {
                  const tag = `{${v}}`;
                  return (
                    <button key={v} type="button" suppressHydrationWarning
                      onClick={() => insertTag(tag)}
                      title={`Insert ${tag}`}
                      style={{ textAlign: "left", padding: "5px 9px", background: "rgba(30,78,140,0.06)", border: "1px solid rgba(30,78,140,0.12)", borderRadius: 4, fontSize: 11, fontFamily: "ui-monospace, monospace", color: "var(--primary)", cursor: "pointer" }}
                      onMouseEnter={e => (e.currentTarget.style.background = "rgba(30,78,140,0.14)")}
                      onMouseLeave={e => (e.currentTarget.style.background = "rgba(30,78,140,0.06)")}>
                      {tag}
                    </button>
                  );
                })}
              </div>
            ) : (
              <div style={{ padding: "8px 14px 14px", fontSize: 12, color: "var(--on-variant)", lineHeight: 1.5 }}>
                Variables will appear here based on the template type.
              </div>
            )}

            {/* Last updated */}
            {!isAddMode && (
              <div style={{ borderTop: "1px solid var(--outline-v)", padding: "12px 14px", fontSize: 11, color: "var(--outline)" }}>
                <div style={{ marginBottom: 2 }}>Last updated</div>
                <div style={{ color: "var(--on-variant)", fontWeight: 500 }}>
                  {new Date(template.updated_at).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" })}
                </div>
                {template.is_builtin && (
                  <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 5 }}>
                    <i className="ti ti-shield-check" style={{ fontSize: 12, color: "var(--success)" }} />
                    <span style={{ color: "var(--success)", fontWeight: 600, fontSize: 11 }}>Built-in template</span>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* ── Attachment bar ── */}
        <div
          onDragOver={e => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          style={{
            flexShrink: 0,
            borderTop: `1.5px ${dragOver ? "dashed" : "solid"} ${dragOver ? "var(--primary)" : "var(--outline-v)"}`,
            background: dragOver ? "rgba(30,78,140,0.03)" : "var(--bg-low)",
            padding: "10px 20px",
            display: "flex",
            alignItems: "center",
            gap: 10,
            minHeight: 52,
            transition: "background 0.12s, border-color 0.12s",
          }}>

          {/* Hidden file input */}
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept={ATTACHMENT_ACCEPT_ATTR}
            style={{ display: "none" }}
            onChange={e => { addFiles(e.target.files); e.target.value = ""; }}
            suppressHydrationWarning
          />

          {/* Attach button */}
          <button type="button" suppressHydrationWarning
            onClick={() => fileInputRef.current?.click()}
            style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 12px", background: "none", border: "1.5px solid var(--outline-v)", borderRadius: "var(--radius)", cursor: "pointer", fontSize: 12, color: "var(--on-variant)", fontFamily: "inherit", flexShrink: 0, whiteSpace: "nowrap" }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = "var(--primary)"; e.currentTarget.style.color = "var(--primary)"; }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = "var(--outline-v)"; e.currentTarget.style.color = "var(--on-variant)"; }}>
            <i className="ti ti-paperclip" style={{ fontSize: 14 }} />
            Attach files
          </button>

          {/* File chips — horizontal scroll */}
          {form.attachments.length === 0 ? (
            <span style={{ fontSize: 12, color: "var(--outline)", fontStyle: "italic" }}>
              {dragOver ? "Drop to attach…" : "PDF, Word, Excel, images"}
            </span>
          ) : (
            <div style={{ display: "flex", gap: 6, overflowX: "auto", flex: 1, alignItems: "center", paddingBottom: 2 }}>
              {form.attachments.map((file, i) => {
                const kind = fileKind(file);
                const meta = FILE_KIND_META[kind];
                const isImg = kind === "image";
                return (
                  <div key={`${file.name}-${i}`} style={{
                    display: "flex", alignItems: "center", gap: 6,
                    padding: "4px 8px 4px 6px",
                    background: "#fff", border: "1px solid var(--outline-v)",
                    borderRadius: 20, flexShrink: 0, maxWidth: 180,
                  }}>
                    {isImg ? (
                      <img
                        src={URL.createObjectURL(file)}
                        alt={file.name}
                        style={{ width: 20, height: 20, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }}
                      />
                    ) : (
                      <div style={{ width: 20, height: 20, borderRadius: "50%", background: meta.bg, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                        <i className={`ti ${meta.icon}`} style={{ fontSize: 11, color: meta.color }} />
                      </div>
                    )}
                    <span style={{ fontSize: 11, color: "var(--on-bg)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 110 }}>
                      {file.name}
                    </span>
                    <button type="button" suppressHydrationWarning
                      onClick={() => removeFile(i)}
                      style={{ background: "none", border: "none", cursor: "pointer", padding: 0, lineHeight: 1, color: "var(--outline)", flexShrink: 0, fontSize: 12 }}
                      onMouseEnter={e => (e.currentTarget.style.color = "var(--error)")}
                      onMouseLeave={e => (e.currentTarget.style.color = "var(--outline)")}>
                      <i className="ti ti-x" style={{ fontSize: 11 }} />
                    </button>
                  </div>
                );
              })}
            </div>
          )}

          {form.attachments.length > 0 && (
            <span style={{ fontSize: 11, color: "var(--outline)", flexShrink: 0, marginLeft: "auto" }}>
              {form.attachments.length} file{form.attachments.length !== 1 ? "s" : ""}
            </span>
          )}
        </div>

        {/* Footer */}
        <div className="modal-footer" style={{ flexShrink: 0 }}>
          <button className="btn btn-ghost" onClick={onClose} disabled={saving} suppressHydrationWarning>Cancel</button>
          <button className="btn btn-filled" onClick={handleSave} disabled={saving} suppressHydrationWarning>
            {saving
              ? <><i className="ti ti-loader-2" style={{ animation: "spin 1s linear infinite" }} /> Saving…</>
              : <><i className="ti ti-device-floppy" /> {isAddMode ? "Create Template" : "Save Template"}</>
            }
          </button>
        </div>

        <style>{`
          [contenteditable]:focus { border-color: var(--primary) !important; }
          @keyframes spin { to { transform: rotate(360deg); } }
        `}</style>
      </div>
    </div>
  );
}
