import type { NextConfig } from 'next'

// Deployed natively on Vercel (Root Directory = `web`), so no `output: 'standalone'`.
const nextConfig: NextConfig = {
  images: {
    unoptimized: true,
  },
}

export default nextConfig
