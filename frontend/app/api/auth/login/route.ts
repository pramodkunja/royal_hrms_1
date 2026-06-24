// Login is now handled client-side (direct backend call).
// This route is kept as a stub in case server-side proxying is needed later.
import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json(
    { error: "Use the backend API directly via NEXT_PUBLIC_API_URL." },
    { status: 410 }
  );
}
