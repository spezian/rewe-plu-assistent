// Public, read-only proxy for REWE product search and its image CDN. Never
// forward caller headers/cookies, accept arbitrary hosts, or follow redirects.
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'apikey, authorization, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'X-Content-Type-Options': 'nosniff',
};
const userAgent = 'RewePLUAssistent/1.0 (eu.dacjan.rewe_plu_assistent; dacjan@mailbox.org)';
const maxBytes = 4 * 1024 * 1024;

function failure(message, status) {
  return Response.json({ error: message }, {
    status, headers: { ...cors, 'Cache-Control': 'no-store' },
  });
}

function imageTarget(raw) {
  let url;
  try { url = new URL(raw); } catch { return null; }
  if (url.protocol !== 'https:' || url.hostname !== 'img.rewe-static.de' ||
      url.port || url.username || url.password || url.hash ||
      !/^\/\d+\/[\w-]+\.(png|jpe?g|webp)$/.test(url.pathname)) return null;
  const width = url.searchParams.get('imwidth') ?? '800';
  if (!['200', '400', '800'].includes(width)) return null;
  // Only the product image transform seen on REWE search cards is forwarded.
  url.search = new URLSearchParams({ impolicy: 's-offers', imwidth: width }).toString();
  return url;
}

async function limitedBody(response) {
  if (Number(response.headers.get('content-length')) > maxBytes) {
    await response.body?.cancel();
    throw new Error('Response too large');
  }
  if (!response.body) throw new Error('Missing body');
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > maxBytes) {
        await reader.cancel();
        throw new Error('Response too large');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}

export function createHandler(fetcher = fetch) {
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (request.method !== 'GET') return failure('Only GET is supported.', 405);
    const params = new URL(request.url).searchParams;
    const query = params.get('query')?.trim();
    const image = params.get('image');
    if (params.has('query') === params.has('image')) return failure('Supply query or image.', 400);
    let target;
    if (image !== null) {
      target = imageTarget(image);
      if (!target) return failure('Invalid product image URL.', 400);
    } else {
      if (!query || query.length > 120) return failure('Invalid search query.', 400);
      target = new URL('https://www.rewe.de/suche/uebersicht');
      target.searchParams.set('searchTerm', query);
    }
    try {
      const response = await fetcher(target, {
        redirect: 'error',
        signal: AbortSignal.timeout(12_000),
        headers: {
          'User-Agent': userAgent,
          'Accept': image !== null ? 'image/png,image/jpeg,image/webp' : 'text/html',
          'Accept-Language': 'de-DE,de;q=0.9',
        },
      });
      if (!response.ok) {
        await response.body?.cancel();
        return failure('REWE request failed.', [403, 429].includes(response.status) ? response.status : 502);
      }
      const contentType = (response.headers.get('content-type') ?? '').split(';')[0].toLowerCase();
      const allowedType = image !== null
        ? ['image/png', 'image/jpeg', 'image/webp'].includes(contentType)
        : contentType === 'text/html';
      if (!allowedType) {
        await response.body?.cancel();
        return failure('Unexpected REWE response.', 502);
      }
      const body = await limitedBody(response);
      return new Response(body, {
        headers: {
          ...cors,
          'Content-Type': image !== null ? contentType : 'text/html; charset=utf-8',
          // HTML is parsed as data by Flutter, never executed in the app. Also
          // prevent scripts if someone navigates directly to this endpoint.
          'Content-Security-Policy': "default-src 'none'; sandbox",
          'Cache-Control': image !== null ? 'public, max-age=86400' : 'public, max-age=300',
        },
      });
    } catch {
      return failure('REWE is currently unavailable.', 502);
    }
  };
}
