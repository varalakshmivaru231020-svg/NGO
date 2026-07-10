import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/session.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plain paths (e.g. /login) instead of hash routing (/#/login). Requires
  // the web server to fall back to index.html for unmatched paths — see the
  // nginx vhost's SPA fallback for the deployed site.
  usePathUrlStrategy();
  // Restore the signed-in role from the saved token before rendering, so a
  // reload keeps the user's scoped access instead of defaulting to admin.
  await restoreSession();
  runApp(const ProviderScope(child: SakshamApp()));
}

class SakshamApp extends ConsumerWidget {
  const SakshamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Saksham Foundation',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
