import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Build autocontenido para Docker: genera .next/standalone/server.js
  // con solo las deps necesarias (incluye 'pg' por tracing).
  output: "standalone",
};

export default nextConfig;
