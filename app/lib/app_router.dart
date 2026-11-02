import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/app_shell.dart';
import 'features/approvals/presentation/approval_center.dart';
import 'features/archives/presentation/archive_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/finance/presentation/finance_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/lender/presentation/lender_workspace.dart';
import 'features/loans/presentation/loans_screen.dart';
import 'features/manager/presentation/account_admin_screen.dart';
import 'features/manager/presentation/audit_screen.dart';
import 'features/manager/presentation/manager_dashboard.dart';
import 'features/qr/presentation/qr_label_studio.dart';
import 'features/qr/presentation/scan_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'shared/models/app_user.dart';

/// Pure route guard, extracted so it can be unit-tested without a widget tree.
String? resolveRedirect(SessionState session, String location) {
  String home() => session.user!.role == UserRole.manager
      ? '/manager/dashboard'
      : '/lender/workspace';

  if (session.status == SessionStatus.expired) {
    return location == '/session-expired' ? null : '/session-expired';
  }
  final public = location == '/login' || location == '/session-expired';
  if (!session.isAuthenticated) return public ? null : '/login';
  if (public || location == '/') return home();
  if (location.startsWith('/manager') &&
      session.user!.role != UserRole.manager) {
    return '/denied';
  }
  if (location.startsWith('/lender') && session.user!.role != UserRole.lender) {
    return '/denied';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the session changes (sign-in, sign-out,
  // idle timeout or a server 401) so guarded pages are left immediately.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) =>
        resolveRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/session-expired',
        builder: (_, _) => const SessionExpiredScreen(),
      ),
      GoRoute(path: '/denied', builder: (_, _) => const AccessDeniedScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.toString(), child: child),
        routes: [
          _page('/manager/dashboard', const ManagerDashboard()),
          _page('/manager/inventory', const InventoryScreen()),
          _page('/manager/scan', const ScanScreen()),
          _page('/manager/loans', const LoansScreen()),
          _page('/manager/approvals', const ApprovalCenter()),
          _page('/manager/archives', const ArchiveScreen()),
          _page('/manager/finance', const FinanceScreen()),
          _page('/manager/reports', const ReportsScreen()),
          _page('/manager/qr-labels', const QrLabelStudio()),
          _page('/manager/audit', const AuditScreen()),
          _page('/manager/accounts', const AccountAdminScreen()),
          _page('/manager/settings', const SettingsScreen()),
          _page('/lender/workspace', const LenderWorkspace()),
          _page('/lender/scan', const ScanScreen(), withMode: true),
          _page('/lender/loans', const LoansScreen(), withHistory: true),
          _page('/lender/inventory', const InventoryScreen()),
          _page('/lender/approvals', const ApprovalCenter()),
          _page('/lender/settings', const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Workspace route not found'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Return to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
});

GoRoute _page(
  String path,
  Widget screen, {
  bool withMode = false,
  bool withHistory = false,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) {
    Widget child = screen;
    if (withMode) {
      final mode = state.uri.queryParameters['mode'];
      child = ScanScreen(
        initialMode: mode == 'return'
            ? ScanMode.returnAsset
            : mode == 'damage'
            ? ScanMode.damage
            : ScanMode.issue,
      );
    }
    if (withHistory) {
      child = LoansScreen(
        initialHistory: state.uri.queryParameters['history'] == 'true',
      );
    }
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, _, child) =>
          MediaQuery.disableAnimationsOf(context)
          ? child
          : FadeTransition(opacity: animation, child: child),
    );
  },
);
