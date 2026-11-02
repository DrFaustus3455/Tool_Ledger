import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/security_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/app_user.dart';
import '../../auth/presentation/session_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _threshold = TextEditingController();
  final _days = TextEditingController();
  final _life = TextEditingController();
  var _initialized = false;
  var _saving = false;
  late AppSettings _draft;
  @override
  void dispose() {
    _threshold.dispose();
    _days.dispose();
    _life.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final threshold = double.tryParse(_threshold.text);
    final days = int.tryParse(_days.text);
    final life = int.tryParse(_life.text);
    if (threshold == null ||
        threshold < 0 ||
        days == null ||
        days < 1 ||
        life == null ||
        life < 1) {
      showAppSnackBar(
        context,
        'Enter a valid threshold and positive day/life values.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authorize business-rule changes'),
        content: const Text(
          'Approval thresholds, return rules and useful-life defaults affect subsequent operations. Production changes require backend authorization and immutable audit logging.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM CHANGES'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workspaceProvider.notifier)
          .updateSettings(
            _draft.copyWith(
              approvalThresholdPkr: threshold,
              defaultReturnDays: days,
              defaultUsefulLifeYears: life,
            ),
            ref.read(sessionProvider).user!,
          );
      if (mounted) {
        showAppSnackBar(
          context,
          'Business rules saved and mock audit event recorded.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateNotifications(AppSettings next) {
    setState(() => _draft = next);
    final user = ref.read(sessionProvider).user!;
    if (user.role == UserRole.lender) {
      ref
          .read(workspaceProvider.notifier)
          .updateNotificationPreferences(next, user)
          .then((_) {
            if (mounted) {
              showAppSnackBar(context, 'Notification preferences saved.');
            }
          })
          .catchError((Object e) {
            if (mounted) showAppSnackBar(context, '$e', error: true);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceProvider);
    final user = ref.watch(sessionProvider).user!;
    final theme = ref.watch(themeModeProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) {
        if (!_initialized) {
          _draft = data.settings;
          _threshold.text = _draft.approvalThresholdPkr.toStringAsFixed(0);
          _days.text = '${_draft.defaultReturnDays}';
          _life.text = '${_draft.defaultUsefulLifeYears}';
          _initialized = true;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Settings & preferences',
                    subtitle: 'Appearance, account security, notifications and manager-controlled business rules.',
                    eyebrow: 'WORKSPACE CONFIGURATION',
                    actions: user.role == UserRole.manager
                        ? [
                            OutlinedButton.icon(
                              onPressed: () => context.go('/manager/accounts'),
                              icon: const Icon(Icons.manage_accounts_outlined),
                              label: const Text('Manage accounts'),
                            ),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _saving ? 'SAVING…' : 'SAVE BUSINESS RULES',
                              ),
                            ),
                          ]
                        : const [],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 900;
                      final preferences = PrecisionPanel(
                        title: 'APPEARANCE & NOTIFICATIONS',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THEME MODE',
                              style: monoStyle(
                                context,
                                size: 9,
                                color: context.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text('LIGHT'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text('DARK'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.settings_suggest_outlined),
                                  label: Text('SYSTEM'),
                                ),
                              ],
                              selected: {theme},
                              onSelectionChanged: (v) => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(v.first),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Preference is stored locally. No authentication token or password is stored in browser localStorage.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Divider(height: 28),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _draft.overdueNotifications,
                              onChanged: (v) => _updateNotifications(
                                _draft.copyWith(overdueNotifications: v),
                              ),
                              title: const Text(
                                'Overdue equipment notifications',
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _draft.approvalNotifications,
                              onChanged: (v) => _updateNotifications(
                                _draft.copyWith(approvalNotifications: v),
                              ),
                              title: const Text(
                                'Approval request notifications',
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _draft.dailyDigest,
                              onChanged: (v) => _updateNotifications(
                                _draft.copyWith(dailyDigest: v),
                              ),
                              title: const Text('Daily operations digest'),
                            ),
                            if (user.role == UserRole.lender)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Notification changes apply immediately for this mock session.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      );
                      final account = PrecisionPanel(
                        title: 'PROFILE & SESSION',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: context.colors.elevated,
                                child: Text(user.displayName[0]),
                              ),
                              title: Text(user.displayName),
                              subtitle: Text(
                                '${user.employeeId} • ${user.role.name.toUpperCase()}\n${user.department}',
                              ),
                            ),
                            const Divider(height: 20),
                            KeyValueRow(
                              label: 'Username',
                              value: user.username,
                              mono: true,
                            ),
                            const KeyValueRow(
                              label: 'Session',
                              value: 'Mock session • no token persisted',
                            ),
                            const KeyValueRow(
                              label: 'Language',
                              value:
                                  'English (US) • localization-ready structure',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const ChangePasswordDialog(),
                              ),
                              icon: const Icon(Icons.password_outlined),
                              label: const Text('Change password'),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Production: secure HttpOnly/Secure/SameSite cookies, manager MFA, server-side Argon2id hashing, CSRF defenses and forced session expiry.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            preferences,
                            const SizedBox(height: 16),
                            account,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: preferences),
                          const SizedBox(width: 16),
                          Expanded(child: account),
                        ],
                      );
                    },
                  ),
                  if (user.role == UserRole.manager) ...[
                    const SizedBox(height: 16),
                    PrecisionPanel(
                      title: 'MANAGER BUSINESS RULES',
                      code: 'BACKEND AUTHORIZATION REQUIRED',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 280,
                                child: TextField(
                                  controller: _threshold,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Lending approval threshold (PKR)',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _days,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Default return duration (days)',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _life,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Default useful life (years)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'RESTRICTED ASSET CATEGORIES',
                            style: monoStyle(
                              context,
                              size: 9,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: data.assets
                                .map((a) => a.equipmentType)
                                .toSet()
                                .map(
                                  (category) => FilterChip(
                                    label: Text(category),
                                    selected: _draft.restrictedCategories
                                        .contains(category),
                                    onSelected: (v) => setState(() {
                                      final values = {
                                        ..._draft.restrictedCategories,
                                      };
                                      v
                                          ? values.add(category)
                                          : values.remove(category);
                                      _draft = _draft.copyWith(
                                        restrictedCategories: values,
                                      );
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'EQUIPMENT CONDITION CATEGORIES',
                            style: monoStyle(
                              context,
                              size: 9,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ..._draft.conditionCategories.map(
                                (v) => Chip(label: Text(v)),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 17),
                                label: const Text('Add category'),
                                onPressed: () async {
                                  final controller = TextEditingController();
                                  final value = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Add condition category',
                                      ),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Category name',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            controller.text.trim(),
                                          ),
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (value != null && value.length > 2) {
                                    setState(
                                      () => _draft = _draft.copyWith(
                                        conditionCategories: {
                                          ..._draft.conditionCategories,
                                          value,
                                        },
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _draft.lenderOperationalExport,
                            onChanged: (v) => setState(
                              () => _draft = _draft.copyWith(
                                lenderOperationalExport: v,
                              ),
                            ),
                            title: const Text(
                              'Allow lender operational exports',
                            ),
                            subtitle: const Text(
                              'Only active loans and lending history; financial and audit datasets remain prohibited.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});
  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  var _loading = false;
  var _complete = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .changePassword(_current.text, _new.text);
      if (mounted) setState(() => _complete = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_complete ? 'Password changed' : 'Change your password'),
    content: SizedBox(
      width: 460,
      child: _complete
          ? const Text(
              'Your mock password change completed. In production, existing sessions are revoked according to server policy and the password is hashed only on the server.',
            )
          : Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _new,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (v) =>
                        SecurityPolicy.validateNewPassword(v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (v) =>
                        v != _new.text ? 'Passwords do not match' : null,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: Text(_complete ? 'Close' : 'Cancel'),
      ),
      if (!_complete)
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'CHANGING…' : 'CHANGE PASSWORD'),
        ),
    ],
  );
}
