import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blueprint_background.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../shared/models/app_user.dart';
import '../data/auth_repository.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.expired = false});
  final bool expired;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: ref.read(rememberedUsernameProvider),
  );
  final _password = TextEditingController();
  var _obscure = true;
  var _remember = true;
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(sessionProvider.notifier)
          .signIn(_username.text, _password.text);
      await ref
          .read(rememberedUsernameProvider.notifier)
          .set(_username.text.trim(), _remember);
      if (!mounted) return;
      context.go(
        user.role == UserRole.manager
            ? '/manager/dashboard'
            : '/lender/workspace',
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _demo(String username) {
    setState(() {
      _username.text = username;
      _password.text = MockAuthRepository.demoPassword;
      _error = null;
    });
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _username.text);
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset access credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your employee username or ID. Production reset links are single-use and issued by the backend.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Username or employee ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request reset'),
          ),
        ],
      ),
    );
    if (sent != true || !mounted) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If the account exists, reset instructions have been requested.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: BlueprintBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: IntrinsicHeight(
                  child: Container(
                    constraints: BoxConstraints(minHeight: wide ? 660 : 0),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      children: [
                        if (wide) Expanded(flex: 11, child: _MissionPanel()),
                        if (wide)
                          Expanded(
                            flex: 9,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 54,
                                vertical: 48,
                              ),
                              child: _form(),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            child: _form(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final c = context.colors;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandMark(),
          const SizedBox(height: 40),
          Text(
            'AUTHORIZED OPERATIONS',
            style: monoStyle(
              context,
              size: 10,
              color: c.accent,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Secure workspace access',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with your employee credentials. Your role is assigned by the authenticated account.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: c.textSecondary),
          ),
          if (widget.expired) ...[
            const SizedBox(height: 18),
            _Notice(
              icon: Icons.schedule,
              color: c.warning,
              text: 'Your session expired. Sign in again to continue; sensitive operations were not completed.',
            ),
          ],
          const SizedBox(height: 28),
          TextFormField(
            controller: _username,
            enabled: !_loading,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Employee username or ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Enter your employee username or ID.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_loading,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password.' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _remember,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _remember = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Remember username')),
              TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Notice(icon: Icons.error_outline, color: c.danger, text: _error!),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _loading ? null : _signIn,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(_loading ? 'AUTHENTICATING…' : 'SIGN IN TO WORKSPACE'),
          ),
          if (!AppConfig.useLiveBackend) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.elevated,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_outlined, size: 17, color: c.warning),
                      const SizedBox(width: 8),
                      Text(
                        'MOCK AUTHENTICATION ENVIRONMENT',
                        style: monoStyle(context, size: 10, color: c.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Demonstration only — no real session security. Password for both accounts: ${MockAuthRepository.demoPassword}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _demo('manager@toolledger.demo'),
                        child: const Text('Fill manager demo'),
                      ),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _demo('lender@toolledger.demo'),
                        child: const Text('Fill lender demo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Production: HTTPS • secure server cookies • Argon2id • manager MFA • backend RBAC',
            textAlign: TextAlign.center,
            style: monoStyle(context, size: 9, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .5)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _MissionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.sidebar,
      child: BlueprintBackground(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, color: c.accent),
                  const SizedBox(width: 10),
                  Text(
                    'PRODUCT SUPPORT / OPERATIONS ONLINE',
                    style: monoStyle(context, size: 10, color: c.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Every asset.\nEvery handover.\nAccountable.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(height: 1.12),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  'Industrial inventory, QR-based lending and financial asset history in one precision workspace.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: c.textSecondary),
                ),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children:
                    ['QR TRACKED', 'DEPRECIATION READY', 'AUDIT PRESERVED']
                        .map(
                          (label) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 16, color: c.accent),
                              const SizedBox(width: 8),
                              Text(label, style: monoStyle(context, size: 10)),
                            ],
                          ),
                        )
                        .toList(),
              ),
              const Spacer(),
              Text(
                'OES / ENGINEERING SYSTEMS',
                style: monoStyle(context, size: 10, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});
  @override
  Widget build(BuildContext context) => const LoginScreen(expired: true);
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: context.colors.danger),
            const SizedBox(height: 20),
            Text(
              'Access denied',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your current role does not permit this workspace. Backend authorization is still required for every production operation.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Return to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}
