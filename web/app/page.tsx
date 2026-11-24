import { Header } from '@/components/Header'
import { MacAppShowcase } from '@/components/MacAppShowcase'
import { FeatureShowcase } from '@/components/FeatureShowcase'
import { OpenCoreSection } from '@/components/OpenCoreSection'
import { Footer } from '@/components/Footer'
import { getLatestRelease } from '@/lib/releases'

export default async function HomePage() {
  // Deduplicated with the root layout's request by Next's fetch cache (revalidate: 300).
  const latestRelease = await getLatestRelease()

  return (
    <div className="min-h-screen bg-canvas text-label">
      <Header release={latestRelease} />
      <main>
        <MacAppShowcase release={latestRelease} />
        <FeatureShowcase />
        <OpenCoreSection release={latestRelease} />
      </main>
      <Footer />
    </div>
  )
}
