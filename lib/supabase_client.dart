import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase 全局客户端
// 从 Supabase 项目设置页面获取这些值，并添加到环境变量或 .env 文件中
const String supabaseUrl =
    'https://lkwhpiylpukjipvtwirz.supabase.co'; // e.g., 'https://your-project.supabase.co'
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxrd2hwaXlscHVramlwdnR3aXJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODg4NDAsImV4cCI6MjA4MDg2NDg0MH0.A6LowcZiXBEdRK9DWVq2V7MIgZqQ910bMuHomvAFcZQ'; // 从项目设置获取

class SupabaseClientManager {
  static final SupabaseClient instance = Supabase.instance.client;

  // 初始化 Supabase（在 main() 中调用）
  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
