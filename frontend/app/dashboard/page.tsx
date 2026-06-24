import { getSession } from "@/lib/session";
import HRDashboard       from "./_components/HRDashboard";
import AdminDashboard    from "./_components/AdminDashboard";
import ManagerDashboard  from "./_components/ManagerDashboard";
import EmployeeDashboard from "./_components/EmployeeDashboard";

function resolveRole(raw: string) {
  const r = raw.toLowerCase().replace(/[\s_-]+/g, "");
  if (r.includes("hradmin") || r === "hr") return "hr";
  if (r.includes("admin"))                  return "admin";
  if (r.includes("manager"))                return "manager";
  return "employee";
}

export default async function DashboardPage() {
  const session = await getSession();
  const roleKey = resolveRole(session?.role ?? "");
  const sess    = session!;

  if (roleKey === "hr")      return <HRDashboard      session={sess} />;
  if (roleKey === "admin")   return <AdminDashboard   session={sess} />;
  if (roleKey === "manager") return <ManagerDashboard session={sess} />;
  return <EmployeeDashboard session={sess} />;
}
