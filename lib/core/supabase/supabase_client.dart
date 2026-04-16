import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialise Supabase once at app start.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

/// Convenient global accessor — mirrors the `createClient()` pattern from the web app.
SupabaseClient get supabase => Supabase.instance.client;
