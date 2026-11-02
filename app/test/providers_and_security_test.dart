import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolledger/core/providers.dart';
import 'package:toolledger/core/security/security_policy.dart';
import 'package:toolledger/features/auth/data/auth_repository.dart';
import 'package:toolledger/features/auth/presentation/session_controller.dart';
import 'package:toolledger/features/finance/data/depreciation_calculator.dart';
import 'package:toolledger/features/qr/data/qr_asset_reference.dart';
import 'package:toolledger/shared/models/app_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'theme and remembered username persist without storing credentials',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await container
          .read(rememberedUsernameProvider.notifier)
          .set('employee@example.com', true);
      expect(preferences.getString('toolledger_theme_mode'), 'dark');
      expect(
        preferences.getString('toolledger_remembered_username'),
        'employee@example.com',
      );
      expect(
        preferences.getKeys().where(
          (key) => key.contains('password') || key.contains('token'),
        ),
        isEmpty,
      );

      final restored = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(restored.dispose);
      expect(restored.read(themeModeProvider), ThemeMode.dark);
      expect(restored.read(rememberedUsernameProvider), 'employee@example.com');
      await restored.read(rememberedUsernameProvider.notifier).set('', false);
      expect(
        preferences.containsKey('toolledger_remembered_username'),
        isFalse,
      );
    },
  );

  test('mock authentication assigns exactly the account role', () async {
    final auth = MockAuthRepository();
    final manager = await auth.signIn(
      ' MANAGER@toolledger.demo ',
      MockAuthRepository.demoPassword,
    );
    final lender = await auth.signIn(
      'lender@toolledger.demo',
      MockAuthRepository.demoPassword,
    );
    expect(manager.role, UserRole.manager);
    expect(lender.role, UserRole.lender);
    await expectLater(
      auth.signIn('manager@toolledger.demo', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test(
    'session expiry revokes authenticated state and sign-out clears identity',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.signIn(
        'lender@toolledger.demo',
        MockAuthRepository.demoPassword,
      );
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
      controller.expire();
      expect(container.read(sessionProvider).status, SessionStatus.expired);
      expect(container.read(sessionProvider).isAuthenticated, isFalse);
      await controller.signOut();
      expect(container.read(sessionProvider).user, isNull);
      expect(
        container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
    },
  );

  test('manual and USB QR input normalize to an opaque asset ID', () {
    expect(QrAssetReference.normalize('  tl-sock-021\n'), 'TL-SOCK-021');
    expect(QrAssetReference.isValid('tl-sock-021'), isTrue);
    expect(QrAssetReference.isValid(''), isFalse);
    expect(
      QrAssetReference.isValid('https://example.com/private-data'),
      isFalse,
    );
  });

  test('image validation accepts only JPG/PNG within five megabytes', () {
    expect(SecurityPolicy.isAllowedImage('evidence.JPG', 1024), isTrue);
    expect(
      SecurityPolicy.isAllowedImage(
        'evidence.png',
        SecurityPolicy.maxImageBytes,
      ),
      isTrue,
    );
    expect(SecurityPolicy.isAllowedImage('evidence.gif', 1024), isFalse);
    expect(
      SecurityPolicy.isAllowedImage(
        'evidence.jpg',
        SecurityPolicy.maxImageBytes + 1,
      ),
      isFalse,
    );
    expect(SecurityPolicy.validateNewPassword('StrongPassword123'), isNull);
    expect(SecurityPolicy.validateNewPassword('weak'), isNotNull);
  });

  test('straight-line depreciation is capped at depreciable cost', () {
    const calculator = DepreciationCalculator();
    final result = calculator.straightLine(
      purchaseCost: 100000,
      residualValue: 10000,
      usefulLifeYears: 5,
      purchaseDate: DateTime(2000),
      valuationDate: DateTime(2030),
    );
    expect(result.accumulated, 90000);
    expect(result.netBookValue, 10000);
    expect(result.ageDays, greaterThan(5 * 365));
    expect(
      () => calculator.straightLine(
        purchaseCost: 100,
        residualValue: 101,
        usefulLifeYears: 5,
        purchaseDate: DateTime(2020),
        valuationDate: DateTime(2021),
      ),
      throwsArgumentError,
    );
  });
}
