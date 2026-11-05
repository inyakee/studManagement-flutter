import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.contains('YOUR_') ||
      key.contains('YOUR_') ||
      url.isEmpty ||
      !key.startsWith('sb_publishable_')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add your Supabase URL and publishable key to config/app.json, then rebuild the app. Never use a database password or secret key here.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  try {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    runApp(
      StudentApp(
        repository: SupabaseStudentRepository(Supabase.instance.client),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The app could not start. Check config/app.json and your connection, then refresh.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
