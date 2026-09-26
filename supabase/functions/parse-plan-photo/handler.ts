type Dependencies = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  sleep: (milliseconds: number) => Promise<void>;
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-market-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maxBytes = 4 * 1024 * 1024;

class RequestError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function readImage(request: Request): Promise<Uint8Array> {
  if (Number(request.headers.get("content-length")) > maxBytes) {
    throw new RequestError(413, "Das Foto ist zu groß (maximal 4 MB).");
  }
  const reader = request.body?.getReader();
  if (!reader) throw new RequestError(400, "Bitte ein Foto auswählen.");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > maxBytes) {
        await reader.cancel();
        throw new RequestError(413, "Das Foto ist zu groß (maximal 4 MB).");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const png = [137, 80, 78, 71, 13, 10, 26, 10].every((byte, index) => bytes[index] === byte);
  if (!jpeg && !png) throw new RequestError(415, "Bitte ein JPG- oder PNG-Foto auswählen.");
  return bytes;
}

export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (request.method !== "POST") return reply(405, { error: "Nur Foto-Uploads sind möglich." });
    try {
      const authorization = request.headers.get("authorization") ?? "";
      if (!/^Bearer \S+$/i.test(authorization)) throw new RequestError(401, "Bitte den Markt erneut öffnen.");
      const marketId = request.headers.get("x-market-id");
      if (!marketId || !/^[0-9a-f-]{36}$/i.test(marketId)) throw new RequestError(400, "Kein gültiger Markt angegeben.");
      const supabaseUrl = deps.env("SUPABASE_URL");
      const publishableKeys = deps.env("SUPABASE_PUBLISHABLE_KEYS");
      const supabaseKey = deps.env("SUPABASE_ANON_KEY") ||
        (publishableKeys ? JSON.parse(publishableKeys).default : undefined);
      if (!supabaseUrl || !supabaseKey) throw new RequestError(503, "Der Fotoimport ist noch nicht eingerichtet.");
      const authHeaders = { authorization, apikey: supabaseKey };
      // verify_jwt is disabled at the gateway for compatibility with signing
      // keys. Verify the user here, then check the existing market/PIN access.
      const user = await deps.fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: authHeaders,
        signal: AbortSignal.timeout(10000),
      });
      if (!user.ok || !(await user.json()).id) throw new RequestError(401, "Die Sitzung ist abgelaufen. Bitte den Markt erneut öffnen.");
      const access = await deps.fetch(`${supabaseUrl}/rest/v1/rpc/current_market_access`, {
        method: "POST",
        headers: { ...authHeaders, "Content-Type": "application/json" },
        body: "{}",
        signal: AbortSignal.timeout(10000),
      });
      if (!access.ok) throw new RequestError(403, "Der Marktzugang konnte nicht bestätigt werden.");
      const sessions = await access.json();
      if (!Array.isArray(sessions) || !sessions.some((session) =>
        session.market_id === marketId && session.access_level === "editor")) {
        throw new RequestError(403, "Der Fotoimport ist nur mit Bearbeitungszugang für diesen Markt möglich.");
      }

      const key = deps.env("AZURE_DOCUMENT_INTELLIGENCE_KEY");
      const rawEndpoint = deps.env("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT");
      if (!key || !rawEndpoint) throw new RequestError(503, "Die Azure-Fotoerkennung ist noch nicht eingerichtet.");
      const endpoint = new URL(rawEndpoint);
      if (endpoint.protocol !== "https:" || endpoint.username || endpoint.password || endpoint.port ||
        !/\.(cognitiveservices\.azure\.com|api\.cognitive\.microsoft\.com)$/.test(endpoint.hostname)) {
        throw new RequestError(503, "Der Azure-Endpunkt ist nicht richtig eingerichtet.");
      }
      const bytes = await readImage(request);
      let binary = "";
      for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
      const deadline = Date.now() + 70000;
      const azureFetch = (url: string, init: RequestInit = {}) => {
        const remaining = deadline - Date.now();
        if (remaining <= 0) throw new RequestError(504, "Die Fotoerkennung dauert zu lange. Bitte später erneut versuchen.");
        return deps.fetch(url, {
          ...init,
          redirect: "error",
          headers: { "Ocp-Apim-Subscription-Key": key, "Content-Type": "application/json" },
          signal: AbortSignal.timeout(Math.min(remaining, 15000)),
        });
      };
      const checkAzure = (response: Response) => {
        if (response.status === 429) throw new RequestError(429, "Azure ist ausgelastet oder das Seitenkontingent ist erreicht. Bitte später erneut versuchen.");
        if (response.status === 400 || response.status === 415) throw new RequestError(400, "Azure konnte das Foto nicht lesen. Bitte ein anderes JPG- oder PNG-Foto verwenden.");
        if (!response.ok) throw new RequestError(502, "Die Azure-Erkennung ist derzeit nicht verfügbar. Bitte die Einrichtung prüfen.");
      };
      const start = await azureFetch(
        `${endpoint.origin}/documentintelligence/documentModels/prebuilt-layout:analyze?api-version=2024-11-30`,
        { method: "POST", body: JSON.stringify({ base64Source: btoa(binary) }) },
      );
      checkAzure(start);
      const location = start.headers.get("operation-location");
      if (!location) throw new RequestError(502, "Azure hat keinen Erkennungsauftrag zurückgegeben.");
      const operation = new URL(location);
      if (operation.origin !== endpoint.origin ||
        !/^\/documentintelligence\/documentModels\/prebuilt-layout\/analyzeResults\/[a-zA-Z0-9-]+$/.test(operation.pathname)) {
        throw new RequestError(502, "Azure hat eine ungültige Antwort zurückgegeben.");
      }
      let retrySeconds = Number(start.headers.get("retry-after")) || 2;
      for (let attempt = 0; attempt < 35; attempt++) {
        await deps.sleep(Math.max(1, Math.min(5, retrySeconds)) * 1000);
        const response = await azureFetch(operation.toString());
        checkAzure(response);
        const result = await response.json();
        if (result.status === "succeeded") {
          if (!Array.isArray(result.analyzeResult?.tables)) throw new RequestError(422, "Auf dem Foto wurde keine Tabelle erkannt.");
          // Return only what the schedule parser needs. Never store/log images,
          // personal data, credentials, or Azure operation URLs here.
          return reply(200, {
            content: result.analyzeResult.content ?? "",
            tables: result.analyzeResult.tables.map((table: { cells: Record<string, unknown>[] }) => ({
              cells: table.cells.map((cell) => ({
                rowIndex: cell.rowIndex,
                columnIndex: cell.columnIndex,
                rowSpan: cell.rowSpan,
                columnSpan: cell.columnSpan,
                content: cell.content,
              })),
            })),
          });
        }
        if (!["running", "notStarted"].includes(result.status)) throw new RequestError(422, "Das Foto konnte nicht ausgewertet werden. Bitte ein besser lesbares Foto verwenden.");
        retrySeconds = Number(response.headers.get("retry-after")) || 2;
      }
      throw new RequestError(504, "Die Fotoerkennung dauert zu lange. Bitte später erneut versuchen.");
    } catch (error) {
      if (error instanceof RequestError) return reply(error.status, { error: error.message });
      return reply(502, { error: "Die Fotoerkennung ist gerade nicht erreichbar. Bitte später erneut versuchen." });
    }
  };
}
