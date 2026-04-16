import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Global Supabase accessors. Call [initSupabase] once at startup before
/// any feature code touches [supabase] or [auth].
late final SupabaseClient supabase;

Future<void> initSupabase() async {
  if (!AppConfig.hasSupabase) {
    // Allow the app to run without Supabase configured for local UI work —
    // screens must handle the "unconfigured" case gracefully.
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    debug: AppConfig.isDev,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  supabase = Supabase.instance.client;
}

/// Convenience shortcut for the auth client.
GoTrueClient get auth => Supabase.instance.client.auth;
