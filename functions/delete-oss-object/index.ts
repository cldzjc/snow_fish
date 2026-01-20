console.log("delete-oss-object module loaded");

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

async function hmacSha1(key: string, data: string) {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    enc.encode(data)
  );
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}

serve(async (req) => {
  console.log("delete-oss-object handler invoked, method:", req.method);

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch (e) {
    console.error("json parse error", e);
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log("body:", body);

  const { publicUrl, dryRun } = body;
  if (!publicUrl) {
    return new Response(JSON.stringify({ error: "publicUrl required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 从 publicUrl 解析 objectKey
  let objectKey = "";
  try {
    const url = new URL(publicUrl);
    objectKey = decodeURIComponent(url.pathname.replace(/^\//, ""));
    console.log("parsed objectKey:", objectKey);
  } catch (e) {
    console.error("url parse error", e);
    return new Response(JSON.stringify({ error: "Invalid publicUrl" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // dry-run: 仅返回解析结果
  if (dryRun === true) {
    console.log("dryRun mode, returning parsed objectKey");
    return new Response(
      JSON.stringify({ ok: true, objectKey, simulated: true }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // 真实删除: 读取 secrets 并生成签名
  const bucket = Deno.env.get("OSS_BUCKET");
  const region = Deno.env.get("OSS_REGION");
  const accessKeyId = Deno.env.get("OSS_ACCESS_KEY_ID");
  const accessKeySecret = Deno.env.get("OSS_ACCESS_KEY_SECRET");

  console.log("secrets present:", {
    bucket: !!bucket,
    region: !!region,
    accessKeyId: !!accessKeyId,
    accessKeySecret: !!accessKeySecret,
  });

  if (!bucket || !region || !accessKeyId || !accessKeySecret) {
    return new Response(
      JSON.stringify({ error: "Missing OSS secrets in environment" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // 生成删除签名
  const expires = Math.floor(Date.now() / 1000) + 60;
  const canonicalString = `DELETE\n\n\n${expires}\n/${bucket}/${objectKey}`;

  try {
    const signature = await hmacSha1(accessKeySecret, canonicalString);

    const deleteUrl =
      `https://${bucket}.${region}.aliyuncs.com/${objectKey}` +
      `?OSSAccessKeyId=${accessKeyId}` +
      `&Expires=${expires}` +
      `&Signature=${encodeURIComponent(signature)}`;

    console.log("delete url generated:", deleteUrl);

    // 执行 DELETE 请求
    const deleteResp = await fetch(deleteUrl, { method: "DELETE" });
    console.log("delete response status:", deleteResp.status);

    if (deleteResp.ok) {
      return new Response(JSON.stringify({ ok: true, objectKey }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } else {
      const errText = await deleteResp.text();
      console.error("delete failed:", deleteResp.status, errText);
      return new Response(
        JSON.stringify({
          error: "OSS delete failed",
          status: deleteResp.status,
          details: errText,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
  } catch (e) {
    console.error("delete error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
