// Server-side axios instance — used inside Next.js API routes to call
// the remote backend. Never imported by client components.
import axios from "axios";
import { API_URL } from "./config";

const serverApi = axios.create({
  baseURL: API_URL,
  timeout: 15000,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// Normalise error shape so callers always get { message, status }
serverApi.interceptors.response.use(
  (res) => res,
  (err) => {
    const message: string =
      err.response?.data?.message ||
      err.response?.data?.error ||
      err.message ||
      "An unexpected error occurred.";
    const status: number = err.response?.status ?? 500;
    return Promise.reject({ message, status });
  }
);

export default serverApi;
