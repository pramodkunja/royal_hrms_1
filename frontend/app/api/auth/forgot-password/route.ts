import { NextRequest, NextResponse } from "next/server";
import serverApi from "@/lib/serverApi";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { identifier } = body as { identifier: string };

    if (!identifier?.trim()) {
      return NextResponse.json(
        { error: "Username or email is required." },
        { status: 400 }
      );
    }

    await serverApi.post("/auth/forgot-password", { identifier: identifier.trim() });

    // Always return 200 — never reveal whether the account exists
    return NextResponse.json({ success: true });
  } catch (err) {
    const { status } = err as { status: number };
    // Still return 200 for 404s so we don't leak account existence
    if (status === 404) return NextResponse.json({ success: true });
    return NextResponse.json({ error: "Unable to process request." }, { status: 500 });
  }
}
