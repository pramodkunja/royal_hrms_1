import { NextRequest, NextResponse } from "next/server";

const AUTH_COOKIE  = "royal_hrms_auth";
const USER_COOKIE  = "royal_hrms_user";
const PUBLIC_PATHS = ["/login"];

const ROUTE_PERMISSIONS: Record<string, string> = {
  "/dashboard/announcements":    "announcements.view",
  "/dashboard/interview-list":   "recruitment.view",
  "/dashboard/candidate-review": "recruitment.view",
  "/dashboard/email-logs":       "recruitment.view",
  "/dashboard/employees":        "employees.view",
  "/dashboard/org-chart":        "employees.view",
  "/dashboard/branches":         "settings.view",
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

function getPermissions(request: NextRequest): string[] {
  const raw = request.cookies.get(USER_COOKIE)?.value;
  if (!raw) return [];
  try {
    const user = JSON.parse(decodeURIComponent(raw));
    return Array.isArray(user.permissions) ? user.permissions : [];
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
