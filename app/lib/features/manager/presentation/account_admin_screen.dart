import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_user.dart';
import '../../auth/presentation/session_controller.dart';

class AccountAdminScreen extends ConsumerWidget {
  const AccountAdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Employee account administration',
                  subtitle: 'Exactly two roles: manager and lender. Mechanics remain borrower records without application accounts.',
                  eyebrow: 'MANAGER / IDENTITY & ACCESS',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const CreateLenderDialog(),
                      ),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Create lender account'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final values = [
                      (
                        'Active accounts',
                        '${data.users.where((u) => u.isActive).length}',
                        Icons.verified_user_outlined,
                      ),
                      (
                        'Active sessions',
                        '${data.users.fold(0, (sum, u) => sum + u.activeSessions)}',
                        Icons.devices_outlined,
                      ),
                      (
                        'Lender accounts',
                        '${data.users.where((u) => u.role == UserRole.lender).length}',
                        Icons.engineering_outlined,
                      ),
                    ];
                    final width =
                        (constraints.maxWidth - 24) /
                        (constraints.maxWidth > 700 ? 3 : 1);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: values
                          .map(
                            (v) => SizedBox(
                              width: width,
                              child: MetricTile(
                                label: v.$1,
                                value: v.$2,
                                icon: v.$3,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                PrecisionPanel(
                  title: 'APPLICATION ACCOUNTS',
                  code: '${data.users.length} USERS',
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.users.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.colors.border),
                    itemBuilder: (context, index) {
                      final user = data.users[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: context.colors.elevated,
                          child: Text(
                            user.displayName[0],
                            style: TextStyle(color: context.colors.accent),
                          ),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(
                          '${user.employeeId} • ${user.username}\n${user.role.name.toUpperCase()} • ${user.department}\nLast login: ${user.lastLogin == null ? 'Never' : DateFormat('dd MMM yyyy HH:mm').format(user.lastLogin!)} • ${user.activeSessions} active sessions',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(
                              label: user.isActive ? 'ACTIVE' : 'DISABLED',
                              tone: user.isActive
                                  ? StatusTone.positive
                                  : StatusTone.danger,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) =>
                                  _accountAction(context, ref, user, action),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    user.isActive
                                        ? 'Disable account'
                                        : 'Enable account',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Text('Initiate password reset'),
                                ),
                                const PopupMenuItem(
                                  value: 'revoke',
                                  child: Text('Revoke all sessions'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                PrecisionPanel(
                  title: 'LOGIN & PERMISSION ACTIVITY',
                  code: 'READ-ONLY AUDIT',
                  child:
                      data.audit
                          .where(
                            (a) =>
                                a.category == 'Security' ||
                                a.category == 'Accounts',
                          )
                          .isEmpty
                      ? const Text(
                          'No security events in the current mock audit window.',
                        )
                      : Column(
                          children: data.audit
                              .where(
                                (a) =>
                                    a.category == 'Security' ||
                                    a.category == 'Accounts',
                              )
                              .map(
                                (a) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.shield_outlined),
                                  title: Text(a.action),
                                  subtitle: Text(
                                    '${a.actor} • ${a.recordId} • ${a.details}\n${DateFormat('dd MMM yyyy HH:mm:ss').format(a.timestamp)}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accountAction(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    String action,
  ) async {
    final labels = {
      'toggle': user.isActive
          ? 'Disable ${user.displayName}?'
          : 'Enable ${user.displayName}?',
      'reset': 'Initiate password reset for ${user.displayName}?',
      'revoke': 'Revoke every session for ${user.displayName}?',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labels[action]!),
        content: const Text(
          'This account-management action is recorded in the audit trail. Production authorization and session revocation must be enforced by the backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final controller = ref.read(workspaceProvider.notifier);
      final manager = ref.read(sessionProvider).user!;
      if (action == 'toggle') {
        await controller.setUserActive(user.id, !user.isActive, manager);
      }
      if (action == 'reset') {
        await controller.initiatePasswordReset(user.id, manager);
      }
      if (action == 'revoke') await controller.revokeSessions(user.id, manager);
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Account action completed and audit event recorded.',
        );
      }
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, '$e', error: true);
    }
  }
}

class CreateLenderDialog extends ConsumerStatefulWidget {
  const CreateLenderDialog({super.key});
  @override
  ConsumerState<CreateLenderDialog> createState() => _CreateLenderDialogState();
}

class _CreateLenderDialogState extends ConsumerState<CreateLenderDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _employee = TextEditingController(text: 'OES-LND-');
  final _username = TextEditingController();
  final _department = TextEditingController(text: 'Product Support');
  var _loading = false;
  @override
  void dispose() {
    _name.dispose();
    _employee.dispose();
    _username.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = AppUser(
        id: 'U-${DateTime.now().microsecondsSinceEpoch}',
        employeeId: _employee.text.trim().toUpperCase(),
        username: _username.text.trim().toLowerCase(),
        displayName: _name.text.trim(),
        role: UserRole.lender,
        department: _department.text.trim(),
        activeSessions: 0,
      );
      await ref
          .read(workspaceProvider.notifier)
          .createLender(user, ref.read(sessionProvider).user!);
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(
          context,
          'Lender account created. Secure activation/reset must be issued by the backend.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create lender account'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No password is collected or stored in this form. Production account activation uses a single-use backend-issued reset flow.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Employee full name',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employee,
                decoration: const InputDecoration(labelText: 'Employee ID'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username / work email',
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Enter a valid work email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _department,
                decoration: const InputDecoration(labelText: 'Department'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Application role'),
                child: Text(
                  'LENDER — operational lending and inventory access only',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: Text(_loading ? 'CREATING…' : 'CREATE ACCOUNT'),
      ),
    ],
  );
  String? _required(String? v) =>
      v == null || v.trim().length < 3 ? 'Enter at least 3 characters' : null;
}
