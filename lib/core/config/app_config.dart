/// Runtime configuration supplied via `--dart-define` or `--dart-define-from-file`.
/// Never hardcode API keys, service-role keys, or client secrets here.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fxrpowjvhdqjtuluudno.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_QF5G74rEbIgwTRugQWNi6A_tAIdlQWg',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static const String supabaseRedirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'com.tabunganpribadi.app://login-callback/',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// 15 minutes inactivity timeout mandated by PRD Section 10.
  static const Duration inactivityTimeout = Duration(minutes: 15);

  /// Pagination batch size for transaction history (PRD Section 23).
  static const int transactionPageSize = 20;

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_REF');
}
