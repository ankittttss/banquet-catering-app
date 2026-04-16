enum AppEnv { dev, staging, prod }

class AppConfig {
  AppConfig._();

  static const String _envName =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static AppEnv get env => switch (_envName.toLowerCase()) {
        'prod' || 'production' => AppEnv.prod,
        'staging' || 'stage' => AppEnv.staging,
        _ => AppEnv.dev,
      };

  static bool get isProd => env == AppEnv.prod;
  static bool get isDev => env == AppEnv.dev;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
