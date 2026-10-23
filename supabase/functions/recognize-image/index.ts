import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type Body = { imageBase64?: string; inputType?: "camera" | "gallery" | "demo" };
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const reply = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
const match = (name: string, aliases: string[], detected: string) => [name, ...aliases].some((x) => { const a = norm(x), b = norm(detected); return a === b || a.includes(b) || b.includes(a); });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return reply({ error: "Only POST is supported." }, 405);
  try {
    const body = await request.json() as Body;
    const imageBase64 = body.imageBase64?.replace(/^data:image\/[^;]+;base64,/, "");
    if (!imageBase64) return reply({ error: "imageBase64 is required." }, 400);
    if (imageBase64.length > 12_000_000) return reply({ error: "Image is too large." }, 413);
    const visionKey = Deno.env.get("GOOGLE_VISION_API_KEY");
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!visionKey || !url || !serviceKey) return reply({ error: "Recognition service is not configured." }, 503);
    const vision = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(visionKey)}`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ requests: [{ image: { content: imageBase64 }, features: [{ type: "LANDMARK_DETECTION", maxResults: 5 }, { type: "LABEL_DETECTION", maxResults: 10 }, { type: "WEB_DETECTION", maxResults: 10 }] }] }),
    });
    const payload = await vision.json();
    if (!vision.ok || payload.responses?.[0]?.error) return reply({ error: "Google Vision could not analyse this image." }, 502);
    const result = payload.responses?.[0] ?? {};
    const landmark = result.landmarkAnnotations?.[0];
    const label = result.labelAnnotations?.[0];
    const web = result.webDetection?.webEntities?.[0];
    const detectedName = landmark?.description ?? web?.description ?? label?.description ?? "Unknown";
    const confidence = landmark?.score ?? web?.score ?? label?.score ?? 0;
    const detectedType = landmark ? "landmark" : "food";
    const admin = createClient(url, serviceKey);
    const table = detectedType === "landmark" ? "landmark_catalogue" : "food_catalogue";
    const { data: candidates, error } = await admin.from(table).select("*").eq("status", "published");
    if (error) return reply({ error: "Catalogue lookup failed." }, 500);
    const matched = (candidates ?? []).find((x) => match(x.name, x.aliases ?? [], detectedName));
    const auth = request.headers.get("Authorization");
    const userClient = auth ? createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", { global: { headers: { Authorization: auth } } }) : null;
    const { data: userData } = userClient ? await userClient.auth.getUser() : { data: { user: null } };
    if (userData.user) await admin.from("recognition_history").insert({ user_id: userData.user.id, input_type: body.inputType ?? "gallery", detected_type: matched ? detectedType : "unknown", detected_name: detectedName, confidence, catalogue_id: matched?.id ?? null, result_payload: { matched: matched ?? null } });
    return reply({ detectedType: matched ? detectedType : "unknown", detectedName, confidence, matchedResult: matched ?? null });
  } catch (_) { return reply({ error: "Invalid recognition request." }, 400); }
});
