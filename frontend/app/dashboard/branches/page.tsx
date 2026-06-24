import { getSession } from "@/lib/session";
import BranchManagement from "./_components/BranchManagement";
import { redirect } from "next/navigation";

export default async function BranchesPage() {
  const session = await getSession();
  if (!session) {
    redirect("/login");
  }

  return <BranchManagement />;
}
