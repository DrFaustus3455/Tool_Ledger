import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../shared/models/app_user.dart';
import 'auth_repository.dart';

/// REST integration for the Spring Boot backend. Enable with
/// `--dart-define=DATA_SOURCE=live`. Requires server-side cookie/CSRF, MFA
/// and authorization to be deployed.
class SpringBootAuthRepository implements AuthRepository {
  SpringBootAuthRepository(this._api);
  final ApiClient _api;

  @override
  Future<AppUser> signIn(String username, String password) async {
    final response = await _call(
      () => _api.post(
        '/api/v1/auth/login',
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );
    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const AuthException('Username or password is incorrect.');
      case 403:
        throw const AuthException(
          'This account is disabled. Contact your manager.',
          code: 'disabled',
        );
      case 429:
        throw const AuthException(
          'Too many attempts. Wait a few minutes and try again.',
          code: 'rate_limited',
        );
      default:
        throw const AuthException(
          'Authentication service unavailable. Retry later.',
          code: 'network',
        );
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final role = UserRole.tryParse(json['role'] as String?);
      if (role == null) {
        throw const AuthException(
          'This account has no permitted workspace role.',
          code: 'invalid_role',
        );
      }
      return AppUser(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        role: role,
        department: json['department'] as String,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'The server returned an unexpected response.',
        code: 'bad_response',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _call(() => _api.post('/api/v1/auth/logout'));
  }

  @override
  Future<void> requestPasswordReset(String username) async {
    await _call(
      () => _api.post(
        '/api/v1/auth/password-reset',
        body: jsonEncode({'username': username}),
      ),
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final response = await _call(
      () => _api.post(
        '/api/v1/auth/password',
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ),
    );
    if (response.statusCode == 400 || response.statusCode == 403) {
      throw const AuthException('Current password is incorrect.');
    }
    if (response.statusCode >= 300) {
      throw const AuthException(
        'Password could not be changed. Retry later.',
        code: 'network',
      );
    }
  }

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw AuthException(e.message, code: 'network');
    }
  }
}
