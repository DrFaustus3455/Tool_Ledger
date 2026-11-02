import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolledger/core/providers.dart';
import 'package:toolledger/core/theme/app_theme.dart';
import 'package:toolledger/features/auth/presentation/login_screen.dart';
import 'package:toolledger/main.dart';

void main() {
  testWidgets('manager dashboard and finance charts render without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const ToolLedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill manager demo'));
    await tester.tap(find.text('SIGN IN TO WORKSPACE'));
    await tester.pumpAndSettle();

    expect(find.text('Operations command center'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Finance & depreciation').first);
    await tester.pumpAndSettle();

    expect(find.text('Finance & depreciation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide login layout renders in a short desktop viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1339, 626);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('AUTHORIZED OPERATIONS'), findsOneWidget);
    expect(find.text('Fill manager demo'), findsOneWidget);
  });

  testWidgets('login validates empty credentials and exposes both demo roles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fill manager demo'), findsOneWidget);
    expect(find.text('Fill lender demo'), findsOneWidget);
    await tester.tap(find.text('SIGN IN TO WORKSPACE'));
    await tester.pump();
    expect(find.text('Enter your employee username or ID.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
}
