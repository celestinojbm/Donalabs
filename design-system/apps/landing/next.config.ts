import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  experimental: {
    // app/global-not-found.tsx: 404 outside the per-locale root layouts
    globalNotFound: true,
  },
  async redirects() {
    return [
      {
        source: "/",
        destination: "/en",
        permanent: false,
      },
    ]
  },
}

export default nextConfig
