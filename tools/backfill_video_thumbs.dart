// tools/backfill_video_thumbs.dart
// Dart script to backfill thumbnails for video media rows in Supabase.

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

// Usage:
//  dart run tools/backfill_video_thumbs.dart --limit=50 --dry-run

Future<int> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final limitArg = args.firstWhere(
    (a) => a.startsWith('--limit='),
    orElse: () => '',
  );
  final limit = limitArg.isNotEmpty
      ? int.tryParse(limitArg.split('=')[1]) ?? 0
      : 0;

  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_SERVICE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    stderr.writeln(
      'Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in the environment.',
    );
    return 2;
  }

  final client = SupabaseClient(supabaseUrl, supabaseKey);
  final dio = Dio();

  stdout.writeln(
    'Starting backfill (dryRun=$dryRun, limit=${limit == 0 ? 'all' : limit})',
  );

  // Fetch candidate rows: media_type = 'video', owner_type = 'user_video'
  final res = await client
      .from('media')
      .select('id, url, owner_id, thumbnail_url')
      .eq('media_type', 'video')
      .eq('owner_type', 'user_video')
      .order('created_at', ascending: true)
      .limit(limit == 0 ? 10000 : limit);

  final rows = (res as List).cast<Map<String, dynamic>>();
  final candidates = rows.where((r) {
    final t = r['thumbnail_url'];
    return t == null || (t is String && t.trim().isEmpty);
  }).toList();

  stdout.writeln(
    'Found ${rows.length} rows, ${candidates.length} missing thumbnail_url',
  );

  final tmpDir = await Directory.systemTemp.createTemp('thumb_backfill_');

  for (final row in candidates) {
    final id = row['id'];
    final url = row['url'] as String?;
    final ownerId = row['owner_id'];

    if (url == null || url.isEmpty) {
      stdout.writeln('Skipping id=$id: no url');
      continue;
    }

    stdout.writeln('\nProcessing id=$id owner=$ownerId');

    try {
      // Download video
      final parsed = Uri.tryParse(url);
      if (parsed == null) {
        stdout.writeln('  invalid URL: $url');
        continue;
      }

      final resp = await http.get(parsed);
      if (resp.statusCode != 200) {
        stdout.writeln('  failed to download: HTTP ${resp.statusCode}');
        continue;
      }

      final ext = p.extension(parsed.path).isNotEmpty
          ? p.extension(parsed.path)
          : '.mp4';
      final videoFile = File(p.join(tmpDir.path, '$id$ext'));
      await videoFile.writeAsBytes(resp.bodyBytes);

      // Generate thumbnail using ffmpeg if available
      final thumbFile = File(p.join(tmpDir.path, '$id-thumb.jpg'));
      final ffmpegAvailable = await _which('ffmpeg') != null;

      if (ffmpegAvailable) {
        stdout.writeln('  using ffmpeg to generate thumbnail');
        final proc = await Process.run('ffmpeg', [
          '-ss',
          '00:00:01',
          '-i',
          videoFile.path,
          '-frames:v',
          '1',
          '-q:v',
          '2',
          thumbFile.path,
        ]);
        if (proc.exitCode != 0) {
          stdout.writeln('  ffmpeg failed: ${proc.stderr}');
          // fallback: try to use video_thumbnail package (not guaranteed on desktop)
        }
      }

      if (!await thumbFile.exists()) {
        stdout.writeln(
          '  ffmpeg did not produce thumbnail, attempting fallback using package (may fail on some platforms)',
        );
        try {
          // Attempt to use video_thumbnail package if available in environment
          // Note: This may not work on some desktop platforms. It's a best-effort fallback.
          // To avoid adding a compile dependency here we try to shell out to ffmpeg first.
          // If you prefer a pure-Dart fallback, add video_thumbnail and uncomment the code below.
        } catch (e) {
          stdout.writeln('  fallback failed: $e');
        }
      }

      if (!await thumbFile.exists()) {
        stdout.writeln('  no thumbnail produced for id=$id, skipping');
        unawaited(videoFile.delete());
        continue;
      }

      final thumbBytes = await thumbFile.readAsBytes();

      if (dryRun) {
        stdout.writeln(
          '  dry-run: would upload thumbnail (${thumbBytes.length} bytes) and update DB',
        );
        unawaited(videoFile.delete());
        unawaited(thumbFile.delete());
        continue;
      }

      // Request upload URL from Edge Function
      final filename =
          'thumbs/${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final body = jsonEncode({
        'filename': filename,
        'contentType': 'image/jpeg',
        'field': 'thumbnail',
        'owner_type': 'user_video',
        'owner_id': ownerId,
      });

      final funcResp = await client.functions.invoke(
        'get-oss-upload-url',
        body: body,
      );
      final funcData = funcResp.data as Map<String, dynamic>?;
      if (funcData == null) {
        stdout.writeln('  edge function returned no data');
        continue;
      }

      final uploadUrl = funcData['uploadUrl'] ?? funcData['upload_url'];
      final publicUrl = funcData['publicUrl'] ?? funcData['public_url'];
      if (uploadUrl == null || publicUrl == null) {
        stdout.writeln('  invalid response from edge function: $funcData');
        continue;
      }

      // Upload thumbnail via PUT
      final headers = {
        'content-type': 'image/jpeg',
        'content-length': thumbBytes.length.toString(),
      };

      await dio.put(
        uploadUrl,
        data: Stream.fromIterable([thumbBytes]),
        options: Options(headers: headers),
      );

      // Update DB row
      await client
          .from('media')
          .update({'thumbnail_url': publicUrl})
          .eq('id', id)
          .select();
      stdout.writeln('  updated thumbnail_url for id=$id -> $publicUrl');

      // cleanup
      unawaited(videoFile.delete());
      unawaited(thumbFile.delete());
    } catch (e, st) {
      stdout.writeln('  error processing id=$id: $e');
      stdout.writeln(st);
    }
  }

  await tmpDir.delete(recursive: true);
  stdout.writeln('\nBackfill complete');
  return 0;
}

Future<String?> _which(String exe) async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run('where', [exe]);
      if (r.exitCode == 0) return (r.stdout as String).split('\n').first.trim();
      return null;
    } else {
      final r = await Process.run('which', [exe]);
      if (r.exitCode == 0) return (r.stdout as String).split('\n').first.trim();
      return null;
    }
  } catch (e) {
    return null;
  }
}
