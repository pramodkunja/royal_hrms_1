"use client";

import { useState } from "react";
import Image from "next/image";
import clientApi from "@/lib/clientApi";
import { saveAuth } from "@/lib/auth";
import type { UserInfo } from "@/lib/auth";
import ForgotPasswordForm from "@/components/auth/ForgotPasswordForm";
import { API } from "@/lib/api/endpoints";

interface LoginApiResponse {
  status: string;
  message: string;
  data: {
    user: {
      id:          string;
      email:       string;
      full_name:   string;
      role:        string;
      branch:      string;
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
      const { data } = await clientApi.post<LoginApiResponse>(API.auth.login, { email, password });
      const d = data.data;
      const user: UserInfo = {
        userId:      d.user.id,
        email:       d.user.email,
        name:        d.user.full_name,
        role:        d.user.role,
        branch:      d.user.branch ?? "",
        permissions: d.user.permissions ?? [],
      };
      saveAuth(user);
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


/* ── Global spin keyframe (Tailwind doesn't define it by default in v2) ── */
const _style = `@keyframes spin { to { transform: rotate(360deg); } }`;
if (typeof document !== "undefined" && !document.getElementById("login-spin")) {
  const s = document.createElement("style");
  s.id = "login-spin";
  s.textContent = _style;
  document.head.appendChild(s);
}
