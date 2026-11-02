import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/security/security_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../data/models/loan_record.dart';

class ReturnDialog extends ConsumerStatefulWidget {
  const ReturnDialog({super.key, required this.asset});
  final ToolAsset asset;
  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  var _damaged = false;
  var _loading = false;
  var _complete = false;
  final _notes = TextEditingController();
  final List<XFile> _evidence = [];
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 2200,
      maxHeight: 2200,
    );
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (!SecurityPolicy.isAllowedImage(file.name, bytes.length)) {
        if (mounted) {
          showAppSnackBar(
            context,
            '${file.name}: use JPG/PNG up to 5 MB.',
            error: true,
          );
        }
        continue;
      }
      if (_evidence.length < 6) setState(() => _evidence.add(file));
    }
  }

  Future<void> _submit() async {
    if (_damaged && _notes.text.trim().length < 10) {
      setState(() => _error = 'Describe the damage in at least 10 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(workspaceProvider.notifier)
          .returnAsset(
            widget.asset.id,
            _damaged,
            _notes.text.trim(),
            ref.read(sessionProvider).user!,
            _evidence.length,
          );
      if (mounted) setState(() => _complete = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    final loan = data?.loans
        .where(
          (l) =>
              l.assetId == widget.asset.id &&
              (l.status == LoanStatus.active || l.status == LoanStatus.overdue),
        )
        .firstOrNull;
    return AlertDialog(
      title: Text(_complete ? 'Return recorded' : 'Receive equipment return'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: _complete
              ? Column(
                  children: [
                    Icon(
                      _damaged
                          ? Icons.health_and_safety_outlined
                          : Icons.check_circle_outline,
                      size: 58,
                      color: _damaged
                          ? context.colors.warning
                          : context.colors.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _damaged ? 'Asset quarantined' : 'Asset available',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _damaged
                          ? 'The loan is closed, a damage record was created, and the asset cannot be reissued.'
                          : 'The active loan is closed and the asset is available for future lending.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : loan == null
              ? const EmptyState(
                  title: 'No active loan',
                  message:
                      'This asset has no active or overdue loan to receive.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACTIVE LOAN RETRIEVED',
                      style: monoStyle(
                        context,
                        size: 10,
                        color: context.colors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(loan.borrowerName),
                      subtitle: Text(
                        '${loan.borrowerEmployeeId} • ${loan.department}\n${loan.workOrder} • Due ${DateFormat('dd MMM yyyy').format(loan.dueDate)}',
                      ),
                      trailing: StatusBadge.loan(loan.status),
                    ),
                    const Divider(height: 26),
                    Text(
                      'PHYSICAL CONDITION INSPECTION',
                      style: monoStyle(
                        context,
                        size: 10,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.check_circle_outline),
                          label: Text('SERVICEABLE'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.report_problem_outlined),
                          label: Text('DAMAGED'),
                        ),
                      ],
                      selected: {_damaged},
                      onSelectionChanged: (v) =>
                          setState(() => _damaged = v.first),
                    ),
                    if (_damaged) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Damage description',
                          hintText: 'Visible defects, affected parts, immediate safety concerns…',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickEvidence,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Add evidence photographs'),
                      ),
                      if (_evidence.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _evidence
                                .map(
                                  (f) => InputChip(
                                    label: Text(f.name),
                                    onDeleted: () =>
                                        setState(() => _evidence.remove(f)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Returning damaged equipment sets QUARANTINED and creates a permanent damage record.',
                        style: TextStyle(
                          color: context.colors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Confirm that the asset, accessories and identification label are present and serviceable. Status will become AVAILABLE.',
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(_complete ? 'Close' : 'Cancel'),
        ),
        if (!_complete && loan != null)
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(
              _damaged
                  ? 'RECORD RETURN & QUARANTINE'
                  : 'CONFIRM SERVICEABLE RETURN',
            ),
          ),
      ],
    );
  }
}
