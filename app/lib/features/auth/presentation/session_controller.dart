import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../shared/models/app_user.dart';
import '../data/auth_repository.dart';
import '../data/spring_boot_auth_repository.dart';

/// Resolves the authentication backend. Defaults to the demo authenticator;
/// build with `--dart-define=DATA_SOURCE=live` to use the Spring Boot API.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useLiveBackend) {
    return SpringBootAuthRepository(ref.watch(apiClientProvider));
  }
  return MockAuthRepository();
});

enum SessionStatus { unauthenticated, authenticated, expired }

class SessionState {
  const SessionState({required this.status, this.user});
  final SessionStatus status;
  final AppUser? user;
  bool get isAuthenticated =>
      status == SessionStatus.authenticated && user != null;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Idle window after which an authenticated session is expired client-side.
/// The backend remains the authority on real session lifetime.
final sessionIdleTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 15),
);

class SessionController extends Notifier<SessionState> {
  Timer? _idleTimer;

  @override
  SessionState build() {
    ref.onDispose(() => _idleTimer?.cancel());
    return const SessionState(status: SessionStatus.unauthenticated);
  }

  Future<AppUser> signIn(String username, String password) async {
    final user = await ref
        .read(authRepositoryProvider)
        .signIn(username, password);
    state = SessionState(status: SessionStatus.authenticated, user: user);
    _restartIdleTimer();
    return user;
  }

  Future<void> signOut() async {
    _idleTimer?.cancel();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } finally {
      // Always clear local identity, even if the server call fails.
      state = const SessionState(status: SessionStatus.unauthenticated);
    }
  }

  /// Called on user interaction; postpones idle expiry.
  void recordActivity() {
    if (state.isAuthenticated) _restartIdleTimer();
  }

  /// Called when the server rejects the session (HTTP 401) or idle time elapses.
  void expire() {
    _idleTimer?.cancel();
    if (!state.isAuthenticated) return;
    state = SessionState(status: SessionStatus.expired, user: state.user);
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(ref.read(sessionIdleTimeoutProvider), expire);
  }

  Future<void> changePassword(String currentPassword, String newPassword) => ref
      .read(authRepositoryProvider)
      .changePassword(currentPassword, newPassword);
}
