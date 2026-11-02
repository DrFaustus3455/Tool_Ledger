import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_settings.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../data/models/loan_record.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key, required this.asset});
  final ToolAsset asset;
  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _employee = TextEditingController();
  final _workOrder = TextEditingController(text: 'WO-GEN-');
  final _purpose = TextEditingController();
  String? _department;
  late DateTime _due;
  var _handover = false;
  var _loading = false;
  var _step = 0;
  CheckoutResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings =
        ref.read(workspaceProvider).value?.settings ?? const AppSettings();
    _due = DateTime.now().add(Duration(days: settings.defaultReturnDays));
  }

  @override
  void dispose() {
    _name.dispose();
    _employee.dispose();
    _workOrder.dispose();
    _purpose.dispose();
    super.dispose();
  }

  CheckoutDraft get _draft => CheckoutDraft(
    assetId: widget.asset.id,
    borrowerName: _name.text.trim(),
    borrowerEmployeeId: _employee.text.trim().toUpperCase(),
    department: _department!,
    workOrder: _workOrder.text.trim(),
    purpose: _purpose.text.trim(),
    dueDate: _due,
  );

  Future<void> _submit() async {
    if (!_handover) {
      setState(
        () =>
            _error = 'Confirm that the physical handover checks are complete.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(workspaceProvider.notifier)
          .requestCheckout(_draft, ref.read(sessionProvider).user!);
      if (mounted) {
        setState(() {
          _result = result;
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _printReceipt() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TOOLLEDGER / EQUIPMENT HANDOVER RECEIPT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Asset: ${widget.asset.id} — ${widget.asset.description}',
              ),
              pw.Text(
                'Borrower: ${_draft.borrowerName} (${_draft.borrowerEmployeeId})',
              ),
              pw.Text('Department: ${_draft.department}'),
              pw.Text('Work order: ${_draft.workOrder}'),
              pw.Text('Purpose: ${_draft.purpose}'),
              pw.Text(
                'Due: ${DateFormat('dd MMM yyyy HH:mm').format(_draft.dueDate)}',
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Physical handover confirmed. Preserve this receipt with the maintenance work order.',
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'ToolLedger_${widget.asset.id}_receipt.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    final requiresApproval =
        data == null ||
        widget.asset.isRestricted ||
        data.settings.restrictedCategories.contains(
          widget.asset.equipmentType,
        ) ||
        widget.asset.totalPurchaseValuePkr >=
            data.settings.approvalThresholdPkr;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(_step == 2 ? 'Transaction result' : 'Issue equipment'),
          ),
          if (_step < 2)
            Text(
              'STEP ${_step + 1} / 2',
              style: monoStyle(context, size: 10, color: context.colors.accent),
            ),
        ],
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.elevated,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.asset.id,
                            style: monoStyle(
                              context,
                              size: 10,
                              color: context.colors.accent,
                            ),
                          ),
                          Text(
                            widget.asset.description,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_outline),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_step == 0)
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BORROWER & WORK ORDER',
                        style: monoStyle(
                          context,
                          size: 10,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _field(_name, 'Borrower name'),
                          _field(_employee, 'Borrower employee ID'),
                          SizedBox(
                            width: 310,
                            child: DropdownButtonFormField<String>(
                              initialValue: _department,
                              decoration: const InputDecoration(
                                labelText: 'Borrowing department',
                              ),
                              items: data?.assets
                                  .map((a) => a.department)
                                  .toSet()
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _department = v),
                              validator: (v) =>
                                  v == null ? 'Select a department' : null,
                            ),
                          ),
                          _field(_workOrder, 'Maintenance work-order number'),
                          _field(
                            _purpose,
                            'Purpose / maintenance task',
                            width: 632,
                            maxLines: 2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _due,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) setState(() => _due = picked);
                        },
                        icon: const Icon(Icons.event),
                        label: Text(
                          'Return deadline: ${DateFormat('dd MMM yyyy').format(_due)}',
                        ),
                      ),
                      if (requiresApproval) ...[
                        const SizedBox(height: 16),
                        _SecurityNote(
                          icon: Icons.verified_user_outlined,
                          color: context.colors.warning,
                          text: 'HIGH-VALUE / RESTRICTED: submission creates a manager approval request. The tool remains unissued until approval and a separate physical-handover confirmation.',
                        ),
                      ],
                    ],
                  ),
                ),
              if (_step == 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONFIRM PHYSICAL HANDOVER',
                      style: monoStyle(
                        context,
                        size: 10,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...[
                      (
                        'Asset',
                        '${widget.asset.id} • ${widget.asset.description}',
                      ),
                      (
                        'Borrower',
                        '${_draft.borrowerName} • ${_draft.borrowerEmployeeId}',
                      ),
                      ('Department', _draft.department),
                      ('Work order', _draft.workOrder),
                      ('Purpose', _draft.purpose),
                      (
                        'Due date',
                        DateFormat('dd MMM yyyy').format(_draft.dueDate),
                      ),
                    ].map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                e.$1,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(child: Text(e.$2)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 28),
                    CheckboxListTile(
                      value: _handover,
                      onChanged: (v) => setState(() => _handover = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I verified availability, condition, borrower identity and physical handover checks.',
                      ),
                      subtitle: Text(
                        requiresApproval
                            ? 'This submits authorization only. No checkout will be recorded yet.'
                            : 'Availability is rechecked when this transaction is recorded.',
                      ),
                    ),
                    _SecurityNote(
                      icon: Icons.shield_outlined,
                      color: context.colors.accent,
                      text: 'Production backend rules are authoritative. UI validation cannot prevent concurrent issues by itself.',
                    ),
                  ],
                ),
              if (_step == 2 && _result != null)
                Column(
                  children: [
                    Icon(
                      _result == CheckoutResult.checkedOut
                          ? Icons.check_circle_outline
                          : Icons.pending_actions_outlined,
                      size: 58,
                      color: _result == CheckoutResult.checkedOut
                          ? context.colors.accent
                          : context.colors.warning,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _result == CheckoutResult.checkedOut
                          ? 'Equipment checked out'
                          : 'Authorization pending',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result == CheckoutResult.checkedOut
                          ? 'The transaction and complete custody history have been recorded. Provide the receipt to the borrower.'
                          : 'The asset has NOT been issued. Track the request in Approval Requests; after manager approval, confirm the physical handover.',
                      textAlign: TextAlign.center,
                    ),
                    if (_result == CheckoutResult.checkedOut) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _printReceipt,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print / save receipt'),
                      ),
                    ],
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _SecurityNote(
                  icon: Icons.error_outline,
                  color: context.colors.danger,
                  text: _error!,
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Rechecking availability and authorization…'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(_step == 2 ? 'Close' : 'Cancel'),
        ),
        if (_step == 0)
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) setState(() => _step = 1);
            },
            child: const Text('REVIEW HANDOVER'),
          ),
        if (_step == 1) ...[
          TextButton(
            onPressed: _loading ? null : () => setState(() => _step = 0),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(
              requiresApproval ? 'SUBMIT AUTHORIZATION' : 'CONFIRM & CHECK OUT',
            ),
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 310,
    int maxLines = 1,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Required'
          : label.contains('employee') && v.trim().length < 4
          ? 'Enter a valid employee ID'
          : null,
    ),
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      border: Border.all(color: color.withValues(alpha: .5)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
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
