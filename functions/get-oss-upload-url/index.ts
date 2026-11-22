import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function hmacSha1(key: string, data: string) {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(key), { name: "HMAC", hash: "SHA-1" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(data));
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Supabase secrets are not configured" }, 500);
  }
  const authClient = createClient(supabaseUrl, anonKey);
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const filename = String(body.filename ?? "");
  const contentType = String(body.contentType ?? "").toLowerCase();
  const ownerType = String(body.owner_type ?? "files").toLowerCase();
  const entityId = typeof body.entity_id === "string" ? body.entity_id : null;
  const extensionByType: Record<string, string> = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
  };
  if (!filename || filename.length > 180) {
    return json({ error: "Invalid filename" }, 400);
  }
  if (!extensionByType[contentType]) {
    return json({ error: "Unsupported image or video type" }, 400);
  }
  const folder = ownerType === "avatar" || ownerType === "user_profiles"
    ? "avatar"
    : ownerType === "cover" ? "cover"
    : ownerType === "video" || ownerType === "videos" || ownerType === "user_video"
    ? "videos"
    : ownerType === "files" ? "files" : null;
  if (!folder) {
    return json({ error: "Unsupported upload purpose" }, 400);
  }
  if (entityId && (folder === "avatar" || folder === "cover")) {
    return json({ error: "Profile media cannot target a post" }, 400);
  }
  if (entityId && folder !== "files" && folder !== "videos") {
    return json({ error: "Invalid post media folder" }, 400);
  }
  if (entityId) {
    const adminClient = createClient(supabaseUrl, serviceKey);
    const { data: entity } = await adminClient
      .from("entities").select("user_id, entity_type, moderation_status")
      .eq("id", entityId).maybeSingle();
    if (!entity || entity.user_id !== authData.user.id || entity.entity_type !== "post") {
      return json({ error: "You cannot upload media for this content" }, 403);
    }
    if (entity.moderation_status && entity.moderation_status !== "visible") {
      return json({ error: "This content is not available for upload" }, 409);
    }
  }

  const accessKeyId = Deno.env.get("OSS_ACCESS_KEY_ID");
  const accessKeySecret = Deno.env.get("OSS_ACCESS_KEY_SECRET");
  const bucket = Deno.env.get("OSS_BUCKET");
  const region = Deno.env.get("OSS_REGION");
  if (!accessKeyId || !accessKeySecret || !bucket || !region) {
    return json({ error: "OSS secrets are not configured" }, 500);
  }

  const objectKey = `snowfish/${authData.user.id}/${folder}/${crypto.randomUUID()}${extensionByType[contentType]}`;
  const expires = Math.floor(Date.now() / 1000) + 60;
  const canonical = `PUT\n\n${contentType}\n${expires}\n/${bucket}/${objectKey}`;
  const signature = await hmacSha1(accessKeySecret, canonical);
  const baseUrl = `https://${bucket}.${region}.aliyuncs.com/${objectKey}`;
  const uploadUrl = `${baseUrl}?OSSAccessKeyId=${encodeURIComponent(accessKeyId)}&Expires=${expires}&Signature=${encodeURIComponent(signature)}`;
  return json({ uploadUrl, publicUrl: baseUrl, objectKey, expires });
});
