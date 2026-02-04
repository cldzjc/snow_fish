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
  // 环境变量检查
  console.log("ENV CHECK", {
    OSS_BUCKET: Deno.env.get("OSS_BUCKET"),
    OSS_REGION: Deno.env.get("OSS_REGION"),
    OSS_ACCESS_KEY_ID: Deno.env.get("OSS_ACCESS_KEY_ID")?.slice(0, 5),
  });

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
    });
  }

  // 支持接收 filename, contentType, owner_type, owner_id
  const { filename, contentType, owner_type, owner_id } = body;
  
  if (!filename) {
    return new Response(JSON.stringify({ error: "filename required" }), {
      status: 400,
    });
  }
  if (!owner_id) {
    return new Response(JSON.stringify({ error: "owner_id required" }), {
      status: 400,
    });
  }

  const accessKeyId = Deno.env.get("OSS_ACCESS_KEY_ID")!;
  const accessKeySecret = Deno.env.get("OSS_ACCESS_KEY_SECRET")!;
  let bucket = Deno.env.get("OSS_BUCKET")!;
  let region = Deno.env.get("OSS_REGION")!;

  // 修复环境变量配置错误：移除重复的 .aliyuncs.com
  if (region && region.includes(".aliyuncs.com")) {
    console.log(`⚠️ REGION 包含 .aliyuncs.com，移除重复部分: ${region}`);
    region = region.replace(".aliyuncs.com", "").trim();
  }
  if (bucket && bucket.includes(".aliyuncs.com")) {
    console.log(`⚠️ BUCKET 包含 .aliyuncs.com，移除重复部分: ${bucket}`);
    bucket = bucket.split(".")[0]; // 只取 bucket 名称部分
  }
  
  console.log("🔧 ENV VALUES", {
    bucket: bucket,
    region: region,
    accessKeyId: accessKeyId?.slice(0, 5) + "***",
  });

  // 根据 owner_type 确定文件夹
  const folderType = (owner_type || "files").toString().toLowerCase();
  let folder = "files";
  if (folderType === "avatar" || folderType === "user_profiles") {
    folder = "avatar";
  } else if (folderType === "cover") {
    folder = "cover";
  } else if (folderType === "video" || folderType === "videos") {
    folder = "videos";
  }

  // 提取文件扩展名
  const timestamp = Date.now();
  let ext = "";
  const pos = filename.lastIndexOf(".");
  if (pos !== -1) {
    ext = filename.substring(pos);
  } else {
    // 根据 contentType 推导扩展名
    if (contentType === "image/jpeg") ext = ".jpg";
    else if (contentType === "image/png") ext = ".png";
    else if (contentType === "video/mp4") ext = ".mp4";
  }

  // objectKey 结构：snowfish/{owner_id}/{folder}/{timestamp}{ext}
  const objectKey = `snowfish/${owner_id}/${folder}/${timestamp}${ext}`;
  const expires = Math.floor(Date.now() / 1000) + 60;

  // 计算签名
  const canonicalString =
    `PUT\n\n${contentType}\n${expires}\n/${bucket}/${objectKey}`;
  const signature = await hmacSha1(accessKeySecret, canonicalString);

  const uploadUrl =
    `https://${bucket}.${region}.aliyuncs.com/${objectKey}` +
    `?OSSAccessKeyId=${accessKeyId}` +
    `&Expires=${expires}` +
    `&Signature=${encodeURIComponent(signature)}`;

  const publicUrl =
    `https://${bucket}.${region}.aliyuncs.com/${objectKey}`;

  console.log("Generated objectKey", { objectKey, owner_id, owner_type });

  return new Response(
    JSON.stringify({
      uploadUrl,
      publicUrl,
      objectKey,
      expires,
    }),
    { headers: { "Content-Type": "application/json" } }
  );
});