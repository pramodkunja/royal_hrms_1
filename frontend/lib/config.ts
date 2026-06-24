// Central configuration — reads from environment variables.
// NEXT_PUBLIC_ vars are available on both server and client.
// Non-prefixed vars (JWT_SECRET) are server-only.

// Base URL of the remote backend server
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "";

// Base path for internal Next.js API routes
export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "/api";
