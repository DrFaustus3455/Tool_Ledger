import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toolledger/app_router.dart';
import 'package:toolledger/core/network/api_client.dart';
import 'package:toolledger/features/auth/data/auth_repository.dart';
import 'package:toolledger/features/auth/data/spring_boot_auth_repository.dart';
import 'package:toolledger/features/auth/presentation/session_controller.dart';
import 'package:toolledger/shared/models/app_user.dart';

const _manager = AppUser(
  id: 'U-1',
  employeeId: 'E-1',
  username: 'm@example.com',
  displayName: 'Manager',
  role: UserRole.manager,
  department: 'Ops',
);
const _lender = AppUser(
  id: 'U-2',
  employeeId: 'E-2',
  username: 'l@example.com',
  displayName: 'Lender',
  role: UserRole.lender,
  department: 'Ops',
);

SessionState _auth(AppUser u) =>
    SessionState(status: SessionStatus.authenticated, user: u);

ApiClient _api(
  Future<http.Response> Function(http.Request) handler, {
  void Function()? onUnauthorized,
  String? Function()? csrf,
  Duration timeout = const Duration(seconds: 2),
}) => ApiClient(
  baseUri: Uri.parse('https://api.example.com'),
  client: MockClient(handler),
  onUnauthorized: onUnauthorized,
  csrfToken: csrf,
  timeout: timeout,
);

void main() {
  group('UserRole.tryParse', () {
    test('accepts known roles case-insensitively', () {
      expect(UserRole.tryParse('MANAGER'), UserRole.manager);
      expect(UserRole.tryParse(' lender '), UserRole.lender);
    });
    test('rejects unknown, admin and empty roles', () {
      expect(UserRole.tryParse('ADMIN'), isNull);
      expect(UserRole.tryParse(''), isNull);
      expect(UserRole.tryParse(null), isNull);
    });
  });

  group('resolveRedirect', () {
    const anon = SessionState(status: SessionStatus.unauthenticated);
    test('anonymous users are sent to login', () {
      expect(resolveRedirect(anon, '/manager/inventory'), '/login');
      expect(resolveRedirect(anon, '/login'), isNull);
    });
    test('authenticated users skip login and land on role home', () {
      expect(resolveRedirect(_auth(_manager), '/login'), '/manager/dashboard');
      expect(resolveRedirect(_auth(_lender), '/'), '/lender/workspace');
    });
    test('role boundaries are enforced', () {
      expect(resolveRedirect(_auth(_lender), '/manager/finance'), '/denied');
      expect(resolveRedirect(_auth(_manager), '/lender/scan'), '/denied');
      expect(resolveRedirect(_auth(_manager), '/manager/finance'), isNull);
    });
    test('expired sessions are forced to the session-expired screen', () {
      final expired = SessionState(
        status: SessionStatus.expired,
        user: _manager,
      );
      expect(resolveRedirect(expired, '/manager/finance'), '/session-expired');
      expect(resolveRedirect(expired, '/login'), '/session-expired');
      expect(resolveRedirect(expired, '/session-expired'), isNull);
    });
  });

  group('SessionController', () {
    test('idle timeout expires an authenticated session', () async {
      final container = ProviderContainer(
        overrides: [
          sessionIdleTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 60),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.signIn(
        'lender@toolledger.demo',
        MockAuthRepository.demoPassword,
      );
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(container.read(sessionProvider).status, SessionStatus.expired);
    });

    test('activity postpones idle expiry', () async {
      final container = ProviderContainer(
        overrides: [
          sessionIdleTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 150),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.signIn(
        'lender@toolledger.demo',
        MockAuthRepository.demoPassword,
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
        controller.recordActivity();
      }
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    test('expire is a no-op when nobody is signed in', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).expire();
      expect(
        container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
    });
  });

  group('ApiClient', () {
    test('rejects non-HTTPS remote base URLs', () {
      expect(
        () => ApiClient(baseUri: Uri.parse('http://api.example.com')),
        throwsArgumentError,
      );
      expect(
        () => ApiClient(baseUri: Uri.parse('http://localhost:8080')),
        returnsNormally,
      );
    });

    test('sends CSRF header on mutating requests only', () async {
      final seen = <String, String?>{};
      final api = _api((req) async {
        seen[req.method] = req.headers['X-XSRF-TOKEN'];
        return http.Response('{}', 200);
      }, csrf: () => 'tok-123');
      await api.get('/x');
      await api.post('/x', body: '{}');
      expect(seen['GET'], isNull);
      expect(seen['POST'], 'tok-123');
    });

    test('401 triggers onUnauthorized', () async {
      var calls = 0;
      final api = _api(
        (_) async => http.Response('', 401),
        onUnauthorized: () => calls++,
      );
      final response = await api.get('/secure');
      expect(response.statusCode, 401);
      expect(calls, 1);
    });

    test('timeouts and network failures map to ApiException', () async {
      final slow = _api(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(slow.get('/x'), throwsA(isA<ApiException>()));
      final down = _api((_) async => throw http.ClientException('boom'));
      await expectLater(down.get('/x'), throwsA(isA<ApiException>()));
    });
  });

  group('SpringBootAuthRepository', () {
    Map<String, Object?> payload(String role) => {
      'id': 'U-9',
      'employeeId': 'E-9',
      'username': 'x@example.com',
      'displayName': 'X',
      'role': role,
      'department': 'Ops',
    };

    test('maps a valid response to the correct role', () async {
      final repo = SpringBootAuthRepository(
        _api((_) async => http.Response(jsonEncode(payload('MANAGER')), 200)),
      );
      final user = await repo.signIn('x@example.com', 'pw');
      expect(user.role, UserRole.manager);
    });

    test('rejects unknown roles instead of defaulting to lender', () async {
      final repo = SpringBootAuthRepository(
        _api((_) async => http.Response(jsonEncode(payload('ADMIN')), 200)),
      );
      await expectLater(
        repo.signIn('x@example.com', 'pw'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'invalid_role'),
        ),
      );
    });

    test('maps status codes to typed auth errors', () async {
      Future<AuthException> failWith(int status) async {
        final repo = SpringBootAuthRepository(
          _api((_) async => http.Response('', status)),
        );
        try {
          await repo.signIn('x', 'y');
        } on AuthException catch (e) {
          return e;
        }
        throw StateError('expected AuthException');
      }

      expect((await failWith(401)).code, 'authentication_failed');
      expect((await failWith(403)).code, 'disabled');
      expect((await failWith(429)).code, 'rate_limited');
      expect((await failWith(503)).code, 'network');
    });

    test('malformed JSON surfaces a safe error', () async {
      final repo = SpringBootAuthRepository(
        _api((_) async => http.Response('not json', 200)),
      );
      await expectLater(
        repo.signIn('x', 'y'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'bad_response'),
        ),
      );
    });
  });
}
