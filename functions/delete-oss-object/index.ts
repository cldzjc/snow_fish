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

const reply = (body: unknown, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!token || !url || !anon || !service) return reply({ error: "Unauthorized" }, 401);

  const authClient = createClient(url, anon);
  const { data: authData, error } = await authClient.auth.getUser(token);
  if (error || !authData.user) return reply({ error: "Invalid session" }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON body" }, 400); }
  const mediaId = typeof body.media_id === "string" ? body.media_id : null;
  const entityId = typeof body.entity_id === "string" ? body.entity_id : null;
  if (!mediaId && !entityId) return reply({ error: "media_id or entity_id is required" }, 400);

  const admin = createClient(url, service);
  const { data: profile } = await admin
    .from("user_profiles").select("role").eq("id", authData.user.id).maybeSingle();
  const isAdmin = profile?.role === "admin";
  let query = admin.from("media").select("id, user_id, entity_id, url, object_key");
  const { data: rows, error: mediaError } = mediaId
    ? await query.eq("id", mediaId)
    : await query.eq("entity_id", entityId);
  if (mediaError) return reply({ error: "Unable to load media" }, 500);
  const media = rows ?? [];
  if (media.length === 0) return reply({ deleted: 0 });
  if (!isAdmin && media.some((item) => item.user_id !== authData.user.id)) {
    return reply({ error: "You cannot delete this media" }, 403);
  }

  const bucket = Deno.env.get("OSS_BUCKET");
  const region = Deno.env.get("OSS_REGION");
  const accessKeyId = Deno.env.get("OSS_ACCESS_KEY_ID");
  const secret = Deno.env.get("OSS_ACCESS_KEY_SECRET");
  if (!bucket || !region || !accessKeyId || !secret) return reply({ error: "OSS is not configured" }, 500);
  let deleted = 0;
  const failed: Array<{ media_id: string; reason: string }> = [];
  for (const item of media) {
    let objectKey = typeof item.object_key === "string" ? item.object_key : null;
    if (!objectKey && typeof item.url === "string") {
      try {
        const parsed = new URL(item.url);
        const expectedHost = `${bucket}.${region}.aliyuncs.com`;
        const candidate = decodeURIComponent(parsed.pathname.replace(/^\/+/, ""));
        if (parsed.host === expectedHost &&
            isSafeObjectKey(candidate, item.user_id)) {
          objectKey = candidate;
        }
      } catch {
        objectKey = null;
      }
    }
    if (!objectKey || !isSafeObjectKey(objectKey, item.user_id)) {
      failed.push({ media_id: item.id, reason: "unsafe or missing object key" });
      continue;
    }
    const expires = Math.floor(Date.now() / 1000) + 60;
    const canonical = `DELETE\n\n\n${expires}\n/${bucket}/${objectKey}`;
    const signature = await hmacSha1(secret, canonical);
    const deleteUrl = `https://${bucket}.${region}.aliyuncs.com/${objectKey}?OSSAccessKeyId=${encodeURIComponent(accessKeyId)}&Expires=${expires}&Signature=${encodeURIComponent(signature)}`;
    const response = await fetch(deleteUrl, { method: "DELETE" });
    if (!response.ok && response.status !== 404) {
      const { error: taskError } = await admin.from("media_deletion_tasks").upsert({
        media_id: item.id,
        user_id: item.user_id,
        object_key: objectKey,
        status: "failed",
        attempts: 1,
        last_error: "OSS delete failed",
        updated_at: new Date().toISOString(),
      }, { onConflict: "media_id" });
      failed.push({
        media_id: item.id,
        reason: taskError
          ? "OSS delete failed and retry task could not be recorded"
          : "OSS delete failed",
      });
      continue;
    }
    const { error: cleanupError } = await admin.from("media").delete().eq("id", item.id);
    if (cleanupError) {
      const { error: taskError } = await admin.from("media_deletion_tasks").upsert({
        media_id: item.id,
        user_id: item.user_id,
        object_key: objectKey,
        status: "failed",
        attempts: 1,
        last_error: "database cleanup failed",
        updated_at: new Date().toISOString(),
      }, { onConflict: "media_id" });
      failed.push({
        media_id: item.id,
        reason: taskError
          ? "database cleanup failed and retry task could not be recorded"
          : "database cleanup failed",
      });
      continue;
    }
    deleted++;
  }
  return reply({
    deleted,
    failed,
    partial: failed.length > 0,
  }, failed.length > 0 ? 502 : 200);
});

function isSafeObjectKey(objectKey: string, userId: string): boolean {
  if (!objectKey || objectKey.includes("..") || objectKey.includes("\\") ||
      objectKey.includes("//")) return false;
  const parts = objectKey.split("/");
  return parts.length === 4 &&
    parts[0] === "snowfish" &&
    parts[1] === userId &&
    ["avatar", "cover", "files", "videos"].includes(parts[2]) &&
    parts[3].length > 0 &&
    !parts[3].includes("?");
}
