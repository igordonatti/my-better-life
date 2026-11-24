import { GITHUB_REPO_URL } from '@/lib/i18n'

export interface LatestReleaseInfo {
  /** Semantic version without the leading `v` (e.g. `1.0.0`). */
  version: string
  /** Raw Git tag (e.g. `v1.0.0`). */
  tagName: string
  /** Direct `.dmg` (or `.zip`) asset URL, or the release page when no asset exists. */
  downloadUrl: string
  releasePageUrl: string
  assetName: string | null
  publishedAt: string | null
  hasDirectDmg: boolean
}

const RELEASES_LATEST_PAGE = `${GITHUB_REPO_URL}/releases/latest`
const RELEASES_LATEST_API = 'https://api.github.com/repos/igordonatti/my-better-life/releases/latest'

export const FALLBACK_RELEASE: LatestReleaseInfo = {
  version: '1.0.0',
  tagName: 'v1.0.0',
  downloadUrl: RELEASES_LATEST_PAGE,
  releasePageUrl: RELEASES_LATEST_PAGE,
  assetName: null,
  publishedAt: null,
  hasDirectDmg: false,
}

interface GitHubReleaseAsset {
  name?: string
  browser_download_url?: string
}

interface GitHubRelease {
  tag_name?: string
  html_url?: string
  published_at?: string | null
  assets?: GitHubReleaseAsset[]
}

function findAsset(assets: GitHubReleaseAsset[], extension: string): GitHubReleaseAsset | undefined {
  return assets.find(
    (asset) =>
      typeof asset.name === 'string' &&
      asset.name.toLowerCase().endsWith(extension) &&
      typeof asset.browser_download_url === 'string'
  )
}

/** Maps a GitHub "latest release" payload to the landing page's download info. */
export function toLatestReleaseInfo(release: GitHubRelease): LatestReleaseInfo {
  const tagName = release.tag_name?.trim() || FALLBACK_RELEASE.tagName
  const version = tagName.replace(/^v/i, '') || FALLBACK_RELEASE.version
  const releasePageUrl = release.html_url || FALLBACK_RELEASE.releasePageUrl
  const assets = Array.isArray(release.assets) ? release.assets : []
  const dmg = findAsset(assets, '.dmg')
  const asset = dmg ?? findAsset(assets, '.zip')

  return {
    version,
    tagName,
    downloadUrl: asset?.browser_download_url ?? releasePageUrl,
    releasePageUrl,
    assetName: asset?.name ?? null,
    publishedAt: release.published_at ?? null,
    hasDirectDmg: Boolean(dmg),
  }
}

/**
 * Fetches the latest GitHub Release, cached for 5 minutes (ISR on Vercel).
 * Never throws: while the repository is private or has no releases yet (404,
 * rate limit, network error) the page falls back to the Releases page link.
 */
export async function getLatestRelease(): Promise<LatestReleaseInfo> {
  try {
    const response = await fetch(RELEASES_LATEST_API, {
      headers: {
        Accept: 'application/vnd.github+json',
        'User-Agent': 'my-better-life-web',
      },
      next: { revalidate: 300 },
    })
    if (!response.ok) return FALLBACK_RELEASE
    const release = (await response.json()) as GitHubRelease
    return toLatestReleaseInfo(release)
  } catch {
    return FALLBACK_RELEASE
  }
}
