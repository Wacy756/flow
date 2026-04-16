// ignore: unused_import — uncomment with Firebase setup
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import — uncomment with Firebase setup
// import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';

// ⚠️  FIREBASE SETUP REQUIRED:
//   Android: add google-services.json to android/app/
//   iOS:     add GoogleService-Info.plist to ios/Runner/
//   Then run: dart pub global activate flutterfire_cli
//             flutterfire configure
//   This generates lib/firebase_options.dart — import and pass to
//   Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env vars before anything else
  await dotenv.load();

  // Boot Supabase
  await initSupabase();

  // Initialise Firebase + push notifications
  // TODO: uncomment once firebase_options.dart is generated:
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  // await PushService.init();

  runApp(
    // Riverpod scope wraps the entire app
    const ProviderScope(child: FlowApp()),
  );
}

class FlowApp extends ConsumerWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
