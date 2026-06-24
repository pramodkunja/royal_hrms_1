"use client";
import axios from "axios";
import type { AxiosError, InternalAxiosRequestConfig } from "axios";
import { API_URL, API_BASE } from "./config";
import { TOKEN_KEY, REFRESH_KEY, clearAuth, updateTokens } from "./auth";

// Endpoints that must never trigger a silent refresh on 401
const AUTH_URLS = [
  "/login/",
  "/token/refresh/",
  "/forgot-password/",
  "/verify-otp/",
  "/reset-password/",
];

// Set to true during intentional logout so in-flight 401s don't show the
// session-expired overlay after the user has already chosen to sign out.
let _intentionalLogout = false;
export function markIntentionalLogout() { _intentionalLogout = true; }

const clientApi = axios.create({
  baseURL: `${API_URL}${API_BASE}`,
  timeout: 15000,
  headers: { "Content-Type": "application/json" },
});

// ── Request: attach access token ──────────────────────────────────────────────
clientApi.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = localStorage.getItem(TOKEN_KEY);
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ── Refresh mutex — one in-flight refresh, others queue ───────────────────────
let isRefreshing = false;
type QueueItem = { resolve: (token: string) => void; reject: (err: unknown) => void };
let refreshQueue: QueueItem[] = [];

function flushQueue(err: unknown, token: string | null) {
  refreshQueue.forEach(({ resolve, reject }) =>
    token ? resolve(token) : reject(err)
  );
  refreshQueue = [];
}

function dispatchSessionExpired() {
  // Reset mutex first so no further refresh attempts are made
  isRefreshing = false;
  refreshQueue = [];
  clearAuth();
  if (typeof window !== "undefined" && !_intentionalLogout) {
    window.dispatchEvent(new CustomEvent("session:expired"));
  }
}

// ── Response: silent refresh on 401, session-expired on refresh failure ────────
type RetryConfig = InternalAxiosRequestConfig & { _retry?: boolean };

clientApi.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const original = err.config as RetryConfig | undefined;

    // Pass through: non-401, already-retried, or auth endpoints
    if (
      err.response?.status !== 401 ||
      !original ||
      original._retry ||
      AUTH_URLS.some(u => original.url?.endsWith(u))
    ) {
      return Promise.reject(normaliseError(err));
    }

    // Cross-tab sync: another tab may have already refreshed the token.
    // If the stored token differs from what we sent, that means a newer token
    // exists — just retry with it instead of starting another refresh.
    if (typeof window !== "undefined") {
      const sentToken    = (original.headers.Authorization as string | undefined)
        ?.replace("Bearer ", "");
      const currentToken = localStorage.getItem(TOKEN_KEY);
      if (currentToken && currentToken !== sentToken) {
        original._retry = true;
        original.headers.Authorization = `Bearer ${currentToken}`;
        return clientApi(original);
      }
    }

    // Queue behind an in-flight refresh
    if (isRefreshing) {
      original._retry = true; // prevent re-entry if the retry itself 401s
      return new Promise((resolve, reject) => {
        refreshQueue.push({
          resolve: (newToken) => {
            original.headers.Authorization = `Bearer ${newToken}`;
            resolve(clientApi(original));
          },
          reject,
        });
      });
    }

    original._retry = true;
    isRefreshing = true;

    const storedRefresh = typeof window !== "undefined"
      ? localStorage.getItem(REFRESH_KEY)
      : null;

    if (!storedRefresh) {
      // No refresh token stored — nothing to attempt
      dispatchSessionExpired();
      return Promise.reject(normaliseError(err));
    }

    try {
      const { data } = await axios.post<{
        data: { access_token: string; refresh_token?: string };
      }>(
        `${API_URL}${API_BASE}/token/refresh/`,
        { refresh_token: storedRefresh },
        { headers: { "Content-Type": "application/json" } }
      );

      const newAccess  = data.data.access_token;
      const newRefresh = data.data.refresh_token;

      updateTokens(newAccess, newRefresh);
      flushQueue(null, newAccess);

      original.headers.Authorization = `Bearer ${newAccess}`;
      return clientApi(original);
    } catch (refreshErr) {
      // Refresh token itself is expired or blacklisted
      flushQueue(refreshErr, null);
      dispatchSessionExpired();
      return Promise.reject(normaliseError(refreshErr));
    } finally {
      isRefreshing = false;
    }
  }
);

// ── Normalise error shape for all callers ─────────────────────────────────────
function normaliseError(err: unknown) {
  const e = err as AxiosError<{ message?: string; error?: string }>;
  const message =
    e?.response?.data?.message ??
    e?.response?.data?.error ??
    (e as { message?: string })?.message ??
    "An unexpected error occurred.";
  const status = e?.response?.status ?? 500;
  return { message, status };
}

export default clientApi;
