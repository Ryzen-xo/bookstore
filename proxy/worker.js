// Free Cloudflare Worker that keeps the Gemini key off the phone.
//   npm i -g wrangler
//   wrangler login
//   wrangler secret put GEMINI_API_KEY      (paste the key here, never in code)
//   wrangler deploy
// Then run the app with:  --dart-define=AI_PROXY_URL=https://<your-worker>.workers.dev

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, GET, OPTIONS',
  'access-control-allow-headers': 'content-type',
};
const hits = new Map(); // best-effort per-isolate rate limit
const LIMIT = 20; // requests per minute per IP

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'content-type': 'application/json' } });

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    if (url.pathname === '/health') return json({ ok: true, keyConfigured: !!env.GEMINI_API_KEY });
    if (req.method !== 'POST' || url.pathname !== '/chat') return json({ error: 'not found' }, 404);
    if (!env.GEMINI_API_KEY) return json({ error: 'GEMINI_API_KEY secret is not set' }, 500);

    const ip = req.headers.get('cf-connecting-ip') || 'anon';
    const now = Date.now();
    const recent = (hits.get(ip) || []).filter((t) => now - t < 60000);
    if (recent.length >= LIMIT) return json({ error: 'slow down' }, 429);
    recent.push(now);
    hits.set(ip, recent);

    const raw = await req.text();
    if (raw.length > 16000) return json({ error: 'request too large' }, 413);
    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      return json({ error: 'bad json' }, 400);
    }

    // Forward only the fields we expect (no arbitrary options from the client).
    const payload = {
      systemInstruction: body.systemInstruction,
      contents: body.contents,
      generationConfig: {
        temperature: Math.min(Number(body.generationConfig?.temperature ?? 0.7), 1),
        maxOutputTokens: Math.min(Number(body.generationConfig?.maxOutputTokens ?? 700), 900),
        responseMimeType: 'application/json',
      },
    };
    const model = env.GEMINI_MODEL || 'gemini-flash-latest';
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(9000),
      });
      return new Response(await r.text(), {
        status: r.status,
        headers: { ...CORS, 'content-type': 'application/json' },
      });
    } catch (e) {
      return json({ error: 'upstream failed', detail: String(e) }, 502);
    }
  },
};
