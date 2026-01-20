Backfill Video Thumbnails
=========================

Purpose
-------
This document explains how to run a local backfill script that generates thumbnails for videos stored in the `media` table and uploads them to Aliyun OSS via your `get-oss-upload-url` Edge Function. It also documents the `delete-oss-object` example Edge Function.

Requirements
-----------
- A local copy of the repository
- Dart SDK (matches your project SDK)
- `ffmpeg` on PATH (recommended for reliable thumbnail generation)
- Supabase project credentials: set `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` (service role key)
- The `get-oss-upload-url` Edge Function deployed and returning `uploadUrl` and `publicUrl` fields

Script: `tools/backfill_video_thumbs.dart`
-----------------------------------------
Usage examples:
- Dry run (no uploads/DB writes):
  dart run tools/backfill_video_thumbs.dart --limit=10 --dry-run

- Run and process up to 50 rows:
  SUPABASE_URL=... SUPABASE_SERVICE_KEY=... dart run tools/backfill_video_thumbs.dart --limit=50

What it does:
1. Queries `media` rows where `media_type = 'video'` and `thumbnail_url` is empty/null.
2. Downloads the video to a temporary location.
3. Uses `ffmpeg` (preferred) to extract a frame at 1s and create a JPEG thumbnail.
4. Requests an upload URL from `get-oss-upload-url` and uploads the thumbnail via PUT.
5. Updates the row's `thumbnail_url` with the returned `publicUrl`.

Notes
-----
- If you don't have `ffmpeg`, the script attempts a best-effort fallback (may not work on desktop platforms). Installing ffmpeg is recommended.
- The script requires the `get-oss-upload-url` function to be available and returning `{ uploadUrl, publicUrl }`.

Edge Function: `delete-oss-object` example
-----------------------------------------
- File: `functions/delete-oss-object/index.ts`
- Purpose: Delete an OSS object given either `publicUrl` or `objectKey` in the request body.
- Env vars required:
  - `OSS_REGION`
  - `OSS_ACCESS_KEY_ID`
  - `OSS_ACCESS_KEY_SECRET`
  - `OSS_BUCKET`
  - `OSS_ENDPOINT` (optional)

Deploy with:
- `supabase functions deploy delete-oss-object`

Usage (client):
- Call via Supabase Functions: `functions.invoke('delete-oss-object', { body: JSON.stringify({ publicUrl }) })`

Security
--------
- Keep `SUPABASE_SERVICE_KEY` and OSS credentials secure. Use CI secrets or local environment variables responsibly.

If you want, I can:
- Run a dry-run (limit=10) locally and share the logs
- Add an optional GitHub Action to run a controlled backfill job (manual trigger)
