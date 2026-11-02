import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'features/auth/presentation/session_controller.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const ToolLedgerApp(),
    ),
  );
}

class ToolLedgerApp extends ConsumerWidget {
  const ToolLedgerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ToolLedger',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            ref.read(sessionProvider.notifier).recordActivity(),
        onPointerSignal: (_) =>
            ref.read(sessionProvider.notifier).recordActivity(),
        child: child ?? const SizedBox.shrink(),
      ),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 220),
      themeAnimationCurve: Curves.easeOut,
    );
  }
}
