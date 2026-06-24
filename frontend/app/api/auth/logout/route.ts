// Logout is now handled client-side (clearAuth clears localStorage + cookies).
// Stub kept for any server-side logout needs.
import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({ success: true });
}
