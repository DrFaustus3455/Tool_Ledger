import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import '../features/auth/presentation/session_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main.'),
);

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'toolledger_theme_mode';
  @override
  ThemeMode build() {
    final value = ref.read(sharedPreferencesProvider).getString(_key);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final rememberedUsernameProvider =
    NotifierProvider<RememberedUsernameController, String>(
      RememberedUsernameController.new,
    );

class RememberedUsernameController extends Notifier<String> {
  static const _key = 'toolledger_remembered_username';
  @override
  String build() => ref.read(sharedPreferencesProvider).getString(_key) ?? '';

  Future<void> set(String username, bool remember) async {
    state = remember ? username : '';
    if (remember) {
      await ref.read(sharedPreferencesProvider).setString(_key, username);
    } else {
      await ref.read(sharedPreferencesProvider).remove(_key);
    }
  }
}

/// Shared HTTP transport for live repositories. A 401 from any call expires
/// the session globally.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUri: Uri.parse(AppConfig.apiBaseUrl),
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
  ref.onDispose(client.close);
  return client;
});
