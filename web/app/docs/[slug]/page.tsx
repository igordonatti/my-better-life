import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getAllDocs, getDocBySlug } from '@/lib/docs'
import { DocsShell } from '@/components/DocsShell'

interface DocPageProps {
  params: Promise<{ slug: string }>
}

export function generateStaticParams() {
  return getAllDocs().map((doc) => ({ slug: doc.slug }))
}

export async function generateMetadata({ params }: DocPageProps): Promise<Metadata> {
  const { slug } = await params
  const doc = getDocBySlug(slug)
  if (!doc) {
    return { title: 'Not Found — My Better Life Docs' }
  }
  return {
    title: `${doc.title.en} — My Better Life Docs`,
    description: doc.description.en,
  }
}

export default async function DocDetailPage({ params }: DocPageProps) {
  const { slug } = await params
  const docs = getAllDocs()
  const currentDoc = docs.find((d) => d.slug === slug)

  if (!currentDoc) {
    notFound()
  }

  return <DocsShell docs={docs} currentDoc={currentDoc} />
}
