export function normalizeSaleorImageUrl(url?: string | null): string | undefined {
  if (!url) return undefined;
  try {
    const api = process.env.NEXT_PUBLIC_SALEOR_API_URL;
    const desiredOrigin = api ? new URL(api).origin : "http://host.docker.internal:8001";

    // Relative paths served by Saleor
    if (url.startsWith("/thumbnail/") || url.startsWith("/media/")) {
      return desiredOrigin + url;
    }

    const parsed = new URL(url);
    // Rewrite localhost/127.0.0.1 and any Saleor media/thumbnail to the desired origin
    const isLocalHost = ["localhost", "127.0.0.1"].includes(parsed.hostname);
    if (
      isLocalHost ||
      parsed.pathname.startsWith("/thumbnail/") ||
      parsed.pathname.startsWith("/media/")
    ) {
      return (
        desiredOrigin + parsed.pathname + parsed.search + parsed.hash
      );
    }
    return url;
  } catch {
    return url;
  }
}
