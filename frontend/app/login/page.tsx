"use client";

import { useState } from "react";
import Image from "next/image";
import clientApi from "@/lib/clientApi";
import { saveAuth } from "@/lib/auth";
import type { UserInfo } from "@/lib/auth";

interface LoginApiResponse {
  status: string;
  message: string;
  data: {
    access_token: string;
    refresh_token: string;
    user: {
      id:          string;
      email:       string;
      full_name:   string;
      role:        string;
      permissions: string[];
    };
  };
}

/* ── Shared input style ── */
const inputCls = "w-full px-3 py-[10px] border-[1.5px] border-[var(--outline-v)] rounded-[var(--radius)] bg-[var(--bg)] text-[var(--on-bg)] text-sm font-[inherit] transition-colors outline-none focus:border-[var(--primary)] focus:bg-white";

/* ── Submit button ── */
const submitCls = "w-full py-[11px] bg-[#1e4e8c] text-white rounded-[var(--radius)] text-sm font-semibold flex items-center justify-center gap-2 cursor-pointer border-none font-[inherit] disabled:opacity-70 disabled:cursor-not-allowed hover:bg-[#163d6e] transition-colors";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [showForgot, setShowForgot] = useState(false);
  const [forgotSent, setForgotSent] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const { data } = await clientApi.post<LoginApiResponse>("/login/", { email, password });
      const d = data.data;
      const user: UserInfo = {
        userId:      d.user.id,
        email:       d.user.email,
        name:        d.user.full_name,
        role:        d.user.role,
        permissions: d.user.permissions ?? [],
      };
      saveAuth(d.access_token, user, d.refresh_token);
      // Full-page navigation — clears the Next.js client RSC cache so a stale
      // session from a previous user (e.g. system_admin) cannot bleed through.
      window.location.href = "/dashboard";
    } catch (err) {
      const { message } = err as { message: string };
      setError(message || "Login failed. Please check your credentials.");
    } finally {
      setLoading(false);
    }
  }

  return (
    /* Full viewport — constant outer boundary at any zoom */
    <div className="flex h-screen w-screen overflow-hidden bg-white">

      <div className="grid w-full h-full overflow-hidden bg-white"
        style={{ gridTemplateColumns: "1.2fr 1fr" }}>

        {/* ── Left Panel ── */}
        <div className="relative min-w-0 overflow-hidden">
          <Image src="/login.jpg" alt="Royal HRMS" fill sizes="(max-width: 768px) 100vw, 60vw" style={{ objectFit: "cover" }} priority />
        </div>

        {/* ── Right Panel ── */}
        <div className="bg-white px-10 py-12 flex flex-col justify-center min-w-0 overflow-y-auto">
          <div className="max-w-[360px] w-full mx-auto">

            {/* Brand icon */}
            <div className="flex justify-center mb-5">
              <div className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl" style={{ background: "rgba(30,78,140,0.1)" }}>👑</div>
            </div>

            <h2 className="text-[22px] font-bold text-center mb-1 text-[var(--on-bg)]" style={{ letterSpacing: "-0.01em" }}>Welcome back</h2>
            <p className="text-[13px] text-center mb-6 text-[var(--on-variant)]">Sign in to your Royal HRMS account</p>

            {error && (
              <div className="flex items-center gap-2 px-3.5 py-2.5 rounded-[var(--radius)] text-[13px] mb-4 border border-[#ffb3ae]"
                style={{ background: "var(--error-c)", color: "var(--error)" }}>
                <span>⚠</span> {error}
              </div>
            )}

            {showForgot ? (
              <ForgotPasswordForm
                onBack={() => { setShowForgot(false); setForgotSent(false); }}
                sent={forgotSent}
                onSend={() => setForgotSent(true)}
              />
            ) : (
              <form onSubmit={handleSubmit} noValidate>
                <div className="mb-3.5">
                  <label className="block text-xs font-medium mb-1.5 text-[var(--on-variant)]" htmlFor="email">Email</label>
                  <input id="email" type="email" className={inputCls} placeholder="you@company.com"
                    value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email" suppressHydrationWarning />
                </div>

                <div className="mb-3.5">
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-xs font-medium text-[var(--on-variant)]" htmlFor="password">Password</label>
                    <button type="button" className="text-xs font-medium text-[var(--primary)] cursor-pointer bg-transparent border-none p-0 font-[inherit]"
                      onClick={() => setShowForgot(true)} suppressHydrationWarning>
                      Forgot password?
                    </button>
                  </div>
                  <div className="relative">
                    <input id="password" type={showPwd ? "text" : "password"} className={`${inputCls} pr-[42px]`}
                      placeholder="Enter your password" value={password} onChange={e => setPassword(e.target.value)}
                      required autoComplete="current-password" suppressHydrationWarning />
                    <button type="button" tabIndex={-1} aria-label={showPwd ? "Hide password" : "Show password"}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 bg-transparent border-none cursor-pointer text-base leading-none p-1 text-[var(--outline)]"
                      onClick={() => setShowPwd(v => !v)} suppressHydrationWarning>
                      {showPwd ? "🙈" : "👁"}
                    </button>
                  </div>
                </div>

                <button type="submit" className={submitCls} disabled={loading} suppressHydrationWarning>
                  {loading && <Spinner />}
                  {loading ? "Signing in…" : "Sign in"}
                </button>
              </form>
            )}

            <p className="text-[11px] text-center mt-4 text-[var(--outline)]">
              Protected by Royal HRMS · Enterprise SSO available
            </p>
          </div>
        </div>

      </div>
    </div>
  );
}

/* ── Spinner ── */
function Spinner() {
  return (
    <span className="w-4 h-4 rounded-full flex-shrink-0"
      style={{ border: "2px solid rgba(255,255,255,0.35)", borderTopColor: "#fff", animation: "spin 0.7s linear infinite" }} />
  );
}

/* ══════════════════════════════════════════════════════
   Forgot Password — 3-step flow
══════════════════════════════════════════════════════ */
type ForgotStep = "email" | "otp" | "reset" | "done";

function ForgotPasswordForm({ onBack }: { onBack: () => void; sent: boolean; onSend: () => void }) {
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
      await clientApi.post("/forgot-password/", { email: emailVal.trim() });
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
        "/verify-otp/", { email: emailVal.trim(), otp: otp.trim() }
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
      await clientApi.post("/reset-password/", { reset_token: resetToken, new_password: newPwd, confirm_password: confirmPwd });
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

/* ── Global spin keyframe (Tailwind doesn't define it by default in v2) ── */
const _style = `@keyframes spin { to { transform: rotate(360deg); } }`;
if (typeof document !== "undefined" && !document.getElementById("login-spin")) {
  const s = document.createElement("style");
  s.id = "login-spin";
  s.textContent = _style;
  document.head.appendChild(s);
}
