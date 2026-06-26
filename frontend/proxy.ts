import { NextRequest, NextResponse } from "next/server";

const AUTH_COOKIE   = "royal_hrms_auth";
const ACCESS_COOKIE = "royal_access_token";
// Remove USER_COOKIE fallback after all users have logged in at least once
// with the updated backend that embeds permissions in the JWT.
const USER_COOKIE   = "royal_hrms_user";
const PUBLIC_PATHS  = ["/login"];

const ROUTE_PERMISSIONS: Record<string, string> = {
  "/dashboard/announcements":    "announcements.view",
  "/dashboard/interview-list":   "recruitment.view",
  "/dashboard/candidate-review": "recruitment.view",
  "/dashboard/email-logs":       "recruitment.view",
  "/dashboard/employees":        "employees.view",
  "/dashboard/org-chart":        "employees.view",
  "/dashboard/branches":         "branches.view",
  "/dashboard/attendance":       "attendance.view",
  "/dashboard/payroll":          "payroll.view",
  "/dashboard/my-payslip":       "payroll.view",
  "/dashboard/leave":            "leave.view",
  "/dashboard/expenses":         "expenses.view",
  "/dashboard/approvals":        "leave.view",
  "/dashboard/separation":       "employees.view",
  "/dashboard/documents":        "documents.view",
  "/dashboard/reports":          "reports.view",
  "/dashboard/audit":            "audit.view",
  "/dashboard/settings":         "settings.view",
};

function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const segment = token.split(".")[1];
    if (!segment) return {};
    const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(base64)) as Record<string, unknown>;
  } catch {
    return {};
  }
}

function getPermissions(request: NextRequest): string[] {
  // Primary: signed httpOnly JWT — permissions baked in at login, tamper-proof.
  const token = request.cookies.get(ACCESS_COOKIE)?.value;
  if (token) {
    const payload = decodeJwtPayload(token);
    if (Array.isArray(payload.permissions)) {
      return payload.permissions as string[];
    }
  }
  // Fallback: unsigned royal_hrms_user cookie for sessions issued before the
  // backend added the permissions claim to the JWT. Remove after all users
  // have logged in at least once with the updated backend.
  const raw = request.cookies.get(USER_COOKIE)?.value;
  if (!raw) return [];
  try {
    const user = JSON.parse(decodeURIComponent(raw)) as { permissions?: unknown };
    return Array.isArray(user.permissions) ? (user.permissions as string[]) : [];
  } catch {
    return [];
  }
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const isPublic        = PUBLIC_PATHS.some((p) => pathname.startsWith(p));
  const isAuthenticated = request.cookies.get(AUTH_COOKIE)?.value === "1";

  if (!isAuthenticated && !isPublic) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (isAuthenticated && pathname === "/login") {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  // Permission check for protected dashboard routes
  if (isAuthenticated && pathname.startsWith("/dashboard")) {
    const matchedRoute = Object.keys(ROUTE_PERMISSIONS)
      .filter(r => pathname === r || pathname.startsWith(r + "/"))
      .sort((a, b) => b.length - a.length)[0];

    if (matchedRoute) {
      const needed = ROUTE_PERMISSIONS[matchedRoute];
      const permissions = getPermissions(request);
      if (!permissions.includes(needed)) {
        return NextResponse.redirect(new URL("/dashboard", request.url));
      }
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|public|api).*)"],
};
