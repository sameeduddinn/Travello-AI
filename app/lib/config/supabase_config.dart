class SupabaseConfig {
  static const String url = 'https://nolkaiqfyixijdxfrbqn.supabase.co';

  // Public key for Flutter client usage.
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vbGthaXFmeWl4aWpkeGZyYnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMjMxOTMsImV4cCI6MjA5MTY5OTE5M30.p2T9eHjREZmO_f_00-900MISKUxZyZ5BGnMdvMBCp3c';

  static bool get isConfigured =>
      anonKey.isNotEmpty && !anonKey.startsWith('REPLACE_WITH_');
}
