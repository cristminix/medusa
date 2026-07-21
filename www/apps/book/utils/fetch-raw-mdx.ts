import { workerCompatibleFetch } from "docs-utils"
import path from "path"

export async function fetchRawMdx(
  origin: string,
  slug: string[]
): Promise<{ content: string; isOverride: boolean } | null> {
  const isCloudflare = !!process.env.CLOUDFLARE_ENV

  async function tryFetchWithFallback(
    filename: string
  ): Promise<string | null> {
    const result = await workerCompatibleFetch<string | null>({
      url: `${origin}/raw-mdx/${[...slug, filename].join("/")}`,
      responseTransformer: async (res) => {
        return res.ok ? res.text() : null
      },
      fallbackAction: async () => null,
      useRemote: isCloudflare,
    })

    if (result !== null) {
      return result
    }

    try {
      const { promises: fs } = await import("fs")
      return await fs.readFile(
        path.join(process.cwd(), "app", ...slug, filename),
        "utf-8"
      )
    } catch {
      return null
    }
  }

  // An `_md-content.mdx` file overrides `page.mdx` if it exists.
  const overrideContent = await tryFetchWithFallback("_md-content.mdx")

  if (overrideContent) {
    return { content: overrideContent, isOverride: true }
  }

  const pageContent = await tryFetchWithFallback("page.mdx")

  return pageContent ? { content: pageContent, isOverride: false } : null
}
