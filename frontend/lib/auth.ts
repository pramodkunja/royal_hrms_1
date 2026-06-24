// Client-side auth helpers — run in the browser only.

export const TOKEN_KEY   = "royal_token";
export const REFRESH_KEY = "royal_refresh";
export const USER_KEY    = "royal_user";
export const AUTH_COOKIE = "royal_hrms_auth";
export const USER_COOKIE = "royal_hrms_user";

const COOKIE_MAX_AGE = 60 * 60 * 8; // 8 hours

export interface UserInfo {
  userId:      string;
  email:       string;
  name:        string;
  role:        string;
  permissions: string[];
}

export function saveAuth(token: string, user: UserInfo, refreshToken?: string) {
  localStorage.setItem(TOKEN_KEY, token);
  if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
  // Simple flag cookie — lets the proxy middleware know the user is authenticated
  document.cookie = `${AUTH_COOKIE}=1; path=/; max-age=${COOKIE_MAX_AGE}; samesite=lax`;
  // User info cookie — lets server components read name/role
  document.cookie = `${USER_COOKIE}=${encodeURIComponent(JSON.stringify(user))}; path=/; max-age=${COOKIE_MAX_AGE}; samesite=lax`;
}

export function updateTokens(accessToken: string, refreshToken?: string) {
  localStorage.setItem(TOKEN_KEY, accessToken);
  if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
}

export function getStoredRefreshToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(REFRESH_KEY);
}

export function clearAuth() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
  document.cookie = `${AUTH_COOKIE}=; path=/; max-age=0`;
  document.cookie = `${USER_COOKIE}=; path=/; max-age=0`;
}

export function getStoredUser(): UserInfo | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as UserInfo) : null;
  } catch {
    return null;
  }
}
