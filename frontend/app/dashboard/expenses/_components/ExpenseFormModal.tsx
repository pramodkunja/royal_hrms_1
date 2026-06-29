"use client";

import { useState, useRef } from "react";

type ExpenseCategory = "Travel" | "Meals" | "Equipment" | "Other";

interface FormState {
  title:       string;
  amount:      string;
  category:    ExpenseCategory | "";
  date:        string;
  description: string;
}

interface NewExpensePayload {
  title:    string;
  amount:   number;
  category: ExpenseCategory;
  date:     string;
  employee: string;
}

interface ExpenseFormModalProps {
  onClose:  () => void;
  onSubmit: (data: NewExpensePayload) => void;
}

const CATEGORIES: { value: ExpenseCategory; label: string; icon: string }[] = [
  { value: "Travel",    label: "Travel",    icon: "ti-plane-departure"      },
  { value: "Meals",     label: "Meals",     icon: "ti-tools-kitchen-2"      },
  { value: "Equipment", label: "Equipment", icon: "ti-device-desktop"       },
  { value: "Other",     label: "Other",     icon: "ti-dots-circle-horizontal" },
];

const EMPTY_FORM: FormState = { title: "", amount: "", category: "", date: "", description: "" };

type FormErrors = Partial<Record<keyof FormState, string>>;

export default function ExpenseFormModal({ onClose, onSubmit }: ExpenseFormModalProps) {
  const [form,       setForm]       = useState<FormState>(EMPTY_FORM);
  const [errors,     setErrors]     = useState<FormErrors>({});
  const [fileName,   setFileName]   = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  function setField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm(prev => ({ ...prev, [key]: value }));
    setErrors(prev => ({ ...prev, [key]: undefined }));
  }

  function validate(): boolean {
    const errs: FormErrors = {};
    if (!form.title.trim())          errs.title    = "Expense title is required.";
    if (!form.amount)                errs.amount   = "Amount is required.";
    else if (Number(form.amount) <= 0) errs.amount = "Amount must be greater than zero.";
    if (!form.category)              errs.category = "Please select a category.";
    if (!form.date)                  errs.date     = "Date is required.";
    setErrors(errs);
    return Object.keys(errs).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;
    onSubmit({
      title:    form.title.trim(),
      amount:   Number(form.amount),
      category: form.category as ExpenseCategory,
      date:     new Date(form.date).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }),
      employee: "You",
    });
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) setFileName(file.name);
  }

  return (
    <div
      className="modal-overlay open"
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="modal"
        style={{ width: "min(560px, 95vw)", maxHeight: "92vh", overflowY: "auto" }}
      >
        <div className="modal-header">
          <div className="modal-title">
            <i className="ti ti-wallet" style={{ marginRight: 8 }} />
            Submit New Expense
          </div>
          <button className="modal-close" onClick={onClose} suppressHydrationWarning>
            <i className="ti ti-x" />
          </button>
        </div>

        <div className="modal-body">
          {/* Title */}
          <div className="field-group mb-16">
            <label className="field-label">
              Expense Title <span style={{ color: "var(--error)" }}>*</span>
            </label>
            <input
              type="text"
              className={`field-input${errors.title ? " field-error" : ""}`}
              placeholder="e.g. Client visit to Mumbai"
              value={form.title}
              onChange={e => setField("title", e.target.value)}
              suppressHydrationWarning
            />
            {errors.title && <p className="field-error-msg">{errors.title}</p>}
          </div>

          {/* Amount + Category */}
          <div className="form-row cols-2">
            <div className="field-group">
              <label className="field-label">
                Amount (₹) <span style={{ color: "var(--error)" }}>*</span>
              </label>
              <input
                type="number"
                min="1"
                className={`field-input${errors.amount ? " field-error" : ""}`}
                placeholder="0.00"
                value={form.amount}
                onChange={e => setField("amount", e.target.value)}
                suppressHydrationWarning
              />
              {errors.amount && <p className="field-error-msg">{errors.amount}</p>}
            </div>
            <div className="field-group">
              <label className="field-label">
                Category <span style={{ color: "var(--error)" }}>*</span>
              </label>
              <select
                className={`field-input${errors.category ? " field-error" : ""}`}
                value={form.category}
                onChange={e => setField("category", e.target.value as ExpenseCategory | "")}
                suppressHydrationWarning
              >
                <option value="">Select category…</option>
                {CATEGORIES.map(c => (
                  <option key={c.value} value={c.value}>{c.label}</option>
                ))}
              </select>
              {errors.category && <p className="field-error-msg">{errors.category}</p>}
            </div>
          </div>

          {/* Date */}
          <div className="field-group mb-16">
            <label className="field-label">
              Date <span style={{ color: "var(--error)" }}>*</span>
            </label>
            <input
              type="date"
              className={`field-input${errors.date ? " field-error" : ""}`}
              value={form.date}
              onChange={e => setField("date", e.target.value)}
              suppressHydrationWarning
            />
            {errors.date && <p className="field-error-msg">{errors.date}</p>}
          </div>

          {/* Description */}
          <div className="field-group mb-16">
            <label className="field-label">Description</label>
            <textarea
              className="field-input"
              rows={3}
              placeholder="Optional notes about this expense…"
              value={form.description}
              onChange={e => setField("description", e.target.value)}
              style={{ resize: "vertical" }}
              suppressHydrationWarning
            />
          </div>

          {/* Receipt upload */}
          <div className="field-group mb-16">
            <label className="field-label">Receipt</label>
            <div
              className="upload-zone"
              style={{ cursor: "pointer" }}
              onClick={() => fileInputRef.current?.click()}
            >
              <i className="ti ti-file-invoice" />
              {fileName ? (
                <>
                  <p style={{ fontWeight: 500, color: "var(--on-bg)", marginTop: 4 }}>{fileName}</p>
                  <small>Click to replace</small>
                </>
              ) : (
                <>
                  <p>Click to upload receipt</p>
                  <small>PDF, JPG, PNG up to 5MB</small>
                </>
              )}
            </div>
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.jpg,.jpeg,.png"
              style={{ display: "none" }}
              onChange={handleFileChange}
            />
          </div>

          {/* Info banner */}
          <div className="alert alert-info" style={{ marginBottom: 0 }}>
            <i className="ti ti-info-circle" />
            <span>
              Your expense will be sent to your manager for approval. Approved expenses are
              reimbursed in the next payroll cycle.
            </span>
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose} suppressHydrationWarning>
            Cancel
          </button>
          <button className="btn btn-filled" onClick={handleSubmit} suppressHydrationWarning>
            <i className="ti ti-send" /> Submit Expense
          </button>
        </div>
      </div>
    </div>
  );
}
