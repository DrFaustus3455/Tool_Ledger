import '../../../shared/models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.code = 'authentication_failed'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  Future<AppUser> signIn(String username, String password);
  Future<void> signOut();
  Future<void> requestPasswordReset(String username);
  Future<void> changePassword(String currentPassword, String newPassword);
}

/// Development-only authenticator. It is never a substitute for server-side
/// password hashing, MFA, rate limiting, secure cookies or authorization.
class MockAuthRepository implements AuthRepository {
  static const demoPassword = 'Demo!234';
  static const demoAccounts = {
    'manager@toolledger.demo': AppUser(
      id: 'U-001',
      employeeId: 'OES-MGR-01',
      username: 'manager@toolledger.demo',
      displayName: 'Ayesha Khan',
      role: UserRole.manager,
      department: 'Product Support',
    ),
    'lender@toolledger.demo': AppUser(
      id: 'U-002',
      employeeId: 'OES-LND-14',
      username: 'lender@toolledger.demo',
      displayName: 'Bilal Ahmed',
      role: UserRole.lender,
      department: 'Product Support',
    ),
  };

  @override
  Future<AppUser> signIn(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 650));
    final normalized = username.trim().toLowerCase();
    if (normalized == 'offline@toolledger.demo') {
      throw const AuthException(
        'Authentication service unavailable. Check your connection and retry.',
        code: 'network',
      );
    }
    if (normalized == 'disabled@toolledger.demo') {
      throw const AuthException(
        'This account is disabled. Contact your manager.',
        code: 'disabled',
      );
    }
    final user = demoAccounts[normalized];
    if (user == null || password != demoPassword) {
      throw const AuthException(
        'Username or password is incorrect. Repeated failures may lock a production account.',
        code: 'invalid_credentials',
      );
    }
    return user;
  }

  @override
  Future<void> signOut() => Future.delayed(const Duration(milliseconds: 150));

  @override
  Future<void> requestPasswordReset(String username) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!username.contains('@') && username.trim().length < 4) {
      throw const AuthException('Enter a valid employee username or ID.');
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (currentPassword != demoPassword) {
      throw const AuthException('Current password is incorrect.');
    }
  }
}
