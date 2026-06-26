"use client";

import { useState } from "react";
import clientApi from "@/lib/clientApi";
import { API } from "@/lib/api/endpoints";

const inputCls = "w-full px-3 py-[10px] border-[1.5px] border-[var(--outline-v)] rounded-[var(--radius)] bg-[var(--bg)] text-[var(--on-bg)] text-sm font-[inherit] transition-colors outline-none focus:border-[var(--primary)] focus:bg-white";
const submitCls = "w-full py-[11px] bg-[#1e4e8c] text-white rounded-[var(--radius)] text-sm font-semibold flex items-center justify-center gap-2 cursor-pointer border-none font-[inherit] disabled:opacity-70 disabled:cursor-not-allowed hover:bg-[#163d6e] transition-colors";

function Spinner() {
  return (
    <span className="w-4 h-4 rounded-full flex-shrink-0"
      style={{ border: "2px solid rgba(255,255,255,0.35)", borderTopColor: "#fff", animation: "spin 0.7s linear infinite" }} />
  );
}

/* Inject the spin keyframe once — guarded so the login page's injection doesn't double-add. */
const _style = `@keyframes spin { to { transform: rotate(360deg); } }`;
if (typeof document !== "undefined" && !document.getElementById("login-spin")) {
  const s = document.createElement("style");
  s.id = "login-spin";
  s.textContent = _style;
  document.head.appendChild(s);
}

type ForgotStep = "email" | "otp" | "reset" | "done";

export default function ForgotPasswordForm({ onBack }: { onBack: () => void; sent: boolean; onSend: () => void }) {
  const [step, setStep] = useState<ForgotStep>("email");
  const [emailVal, setEmailVal] = useState("");
  const [otp, setOtp] = useState("");
  const [resetToken, setResetToken] = useState("");
  const [newPwd, setNewPwd] = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function sendForgot(e: React.FormEvent) {
    e.preventDefault();
    if (!emailVal.trim()) { setError("Please enter your email address."); return; }
    setLoading(true); setError("");
    try {
      await clientApi.post(API.auth.forgotPassword, { email: emailVal.trim() });
      setStep("otp");
    } catch (err) {
      const { message } = err as { message: string };
      setError(message || "Unable to send OTP. Please try again.");
    } finally { setLoading(false); }
  }

  async function verifyOtp(e: React.FormEvent) {
    e.preventDefault();
    if (!otp.trim()) { setError("Please enter the OTP."); return; }
    setLoading(true); setError("");
    try {
      const { data } = await clientApi.post<{ data?: { reset_token?: string }; reset_token?: string }>(
        API.auth.verifyOtp, { email: emailVal.trim(), otp: otp.trim() }
      );
      const token = data?.data?.reset_token ?? (data as Record<string, unknown>).reset_token as string ?? "";
      setResetToken(token);
      setStep("reset");
    } catch (err) {
      const { message } = err as { message: string };
      setError(message || "Invalid or expired OTP.");
    } finally { setLoading(false); }
  }

  async function resetPassword(e: React.FormEvent) {
    e.preventDefault();
    if (!newPwd) { setError("Enter your new password."); return; }
    if (newPwd !== confirmPwd) { setError("Passwords do not match."); return; }
    setLoading(true); setError("");
    try {
      await clientApi.post(API.auth.resetPassword, { reset_token: resetToken, new_password: newPwd, confirm_password: confirmPwd });
      setStep("done");
    } catch (err) {
      const { message } = err as { message: string };
      setError(message || "Password reset failed. Please try again.");
    } finally { setLoading(false); }
  }

  const ErrorBanner = ({ msg }: { msg: string }) => (
    <div className="flex items-center gap-2 px-3.5 py-2.5 rounded-[var(--radius)] text-[13px] mb-4 border border-[#ffb3ae]"
      style={{ background: "var(--error-c)", color: "var(--error)" }}>
      <span>⚠</span> {msg}
    </div>
  );

  if (step === "done") {
    return (
      <div className="text-center py-2">
        <div className="text-[40px] mb-3.5">✅</div>
        <p className="text-[13px] text-[var(--on-variant)] leading-relaxed">Your password has been reset. You can now sign in with your new password.</p>
        <button type="button" className={`${submitCls} mt-4`} onClick={onBack} suppressHydrationWarning>Back to sign in</button>
      </div>
    );
  }

  return (
    <div>
      <button type="button" onClick={onBack}
        className="bg-transparent border-none p-0 text-xs font-medium cursor-pointer mb-5 inline-flex items-center gap-1 text-[var(--on-variant)] font-[inherit]"
        suppressHydrationWarning>
        ← Back to sign in
      </button>

      {step === "email" && (
        <>
          <h3 className="text-lg font-bold text-[var(--on-bg)] mb-2" style={{ letterSpacing: "-0.01em" }}>Reset your password</h3>
          <p className="text-[13px] text-[var(--on-variant)] mb-5 leading-relaxed">Enter your registered email and we&apos;ll send you a one-time code.</p>
          {error && <ErrorBanner msg={error} />}
          <form onSubmit={sendForgot} noValidate>
            <div className="mb-3.5">
              <label className="block text-xs font-medium mb-1.5 text-[var(--on-variant)]" htmlFor="forgot-email">Email</label>
              <input id="forgot-email" type="email" className={inputCls} placeholder="you@company.com"
                value={emailVal} onChange={e => setEmailVal(e.target.value)} required autoComplete="email" autoFocus suppressHydrationWarning />
            </div>
            <button type="submit" className={submitCls} disabled={loading} suppressHydrationWarning>
              {loading && <Spinner />}
              {loading ? "Sending…" : "Send OTP"}
            </button>
          </form>
        </>
      )}

      {step === "otp" && (
        <>
          <h3 className="text-lg font-bold text-[var(--on-bg)] mb-2" style={{ letterSpacing: "-0.01em" }}>Enter OTP</h3>
          <p className="text-[13px] text-[var(--on-variant)] mb-5 leading-relaxed">A 6-digit code was sent to <strong>{emailVal}</strong>.</p>
          {error && <ErrorBanner msg={error} />}
          <form onSubmit={verifyOtp} noValidate>
            <div className="mb-3.5">
              <label className="block text-xs font-medium mb-1.5 text-[var(--on-variant)]" htmlFor="otp">One-time code</label>
              <input id="otp" type="text" inputMode="numeric" pattern="[0-9]*" maxLength={6}
                className={inputCls} placeholder="123456" value={otp}
                onChange={e => setOtp(e.target.value.replace(/\D/g, ""))} required autoFocus suppressHydrationWarning />
            </div>
            <button type="submit" className={submitCls} disabled={loading} suppressHydrationWarning>
              {loading && <Spinner />}
              {loading ? "Verifying…" : "Verify OTP"}
            </button>
            <button type="button" className="block mt-2.5 text-[13px] text-[var(--primary)] bg-transparent border-none cursor-pointer font-[inherit] p-0"
              onClick={() => { setStep("email"); setError(""); setOtp(""); }} suppressHydrationWarning>
              Resend code
            </button>
          </form>
        </>
      )}

      {step === "reset" && (
        <>
          <h3 className="text-lg font-bold text-[var(--on-bg)] mb-2" style={{ letterSpacing: "-0.01em" }}>Set new password</h3>
          <p className="text-[13px] text-[var(--on-variant)] mb-5 leading-relaxed">Choose a strong password for your account.</p>
          {error && <ErrorBanner msg={error} />}
          <form onSubmit={resetPassword} noValidate>
            <div className="mb-3.5">
              <label className="block text-xs font-medium mb-1.5 text-[var(--on-variant)]" htmlFor="new-pwd">New password</label>
              <div className="relative">
                <input id="new-pwd" type={showNew ? "text" : "password"} className={`${inputCls} pr-[42px]`}
                  placeholder="New password" value={newPwd} onChange={e => setNewPwd(e.target.value)} required autoFocus suppressHydrationWarning />
                <button type="button" tabIndex={-1} className="absolute right-2.5 top-1/2 -translate-y-1/2 bg-transparent border-none cursor-pointer text-base p-1 text-[var(--outline)]"
                  onClick={() => setShowNew(v => !v)} suppressHydrationWarning>{showNew ? "🙈" : "👁"}</button>
              </div>
            </div>
            <div className="mb-3.5">
              <label className="block text-xs font-medium mb-1.5 text-[var(--on-variant)]" htmlFor="confirm-pwd">Confirm password</label>
              <div className="relative">
                <input id="confirm-pwd" type={showConfirm ? "text" : "password"} className={`${inputCls} pr-[42px]`}
                  placeholder="Confirm password" value={confirmPwd} onChange={e => setConfirmPwd(e.target.value)} required suppressHydrationWarning />
                <button type="button" tabIndex={-1} className="absolute right-2.5 top-1/2 -translate-y-1/2 bg-transparent border-none cursor-pointer text-base p-1 text-[var(--outline)]"
                  onClick={() => setShowConfirm(v => !v)} suppressHydrationWarning>{showConfirm ? "🙈" : "👁"}</button>
              </div>
            </div>
            <button type="submit" className={submitCls} disabled={loading} suppressHydrationWarning>
              {loading && <Spinner />}
              {loading ? "Resetting…" : "Reset password"}
            </button>
          </form>
        </>
      )}
    </div>
  );
}
