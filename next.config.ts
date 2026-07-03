import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Served under https://ngo.bestprime.live/admin (path-based, same domain as
  // the Flutter app), reverse-proxied by nginx to this app's own pm2 process.
  basePath: '/admin',
};

export default nextConfig;
