import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/security/security_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/asset_photo.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_user.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/models/tool_asset.dart';

Future<void> showAssetProfile(BuildContext context, String assetId) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close asset profile',
    barrierColor: context.colors.background.withValues(alpha: .72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: dialogContext.colors.surface,
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width < 760
              ? MediaQuery.sizeOf(dialogContext).width
              : 720,
          height: double.infinity,
          child: AssetProfile(assetId: assetId),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

class AssetProfile extends ConsumerStatefulWidget {
  const AssetProfile({super.key, required this.assetId});
  final String assetId;
  @override
  ConsumerState<AssetProfile> createState() => _AssetProfileState();
}

class _AssetProfileState extends ConsumerState<AssetProfile> {
  var _tab = 0;
  var _uploading = false;

  Future<void> _uploadPhoto(ToolAsset asset) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (!SecurityPolicy.isAllowedImage(file.name, bytes.length)) {
      showAppSnackBar(
        context,
        'Use a JPG or PNG image no larger than 5 MB.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview equipment photograph'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${file.name} • ${(bytes.length / 1024).toStringAsFixed(0)} KB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Production uploads require backend-authorized private storage and server-side MIME validation.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload photograph'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _uploading = true);
    try {
      final mime = file.name.toLowerCase().endsWith('png')
          ? 'image/png'
          : 'image/jpeg';
      await ref
          .read(workspaceProvider.notifier)
          .updatePhoto(
            asset.id,
            'data:$mime;base64,${base64Encode(bytes)}',
            ref.read(sessionProvider).user!,
          );
      if (mounted) {
        showAppSnackBar(
          context,
          'Equipment photograph updated in the mock private record.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    final asset = data?.assetById(widget.assetId);
    final user = ref.watch(sessionProvider).user;
    if (asset == null || data == null || user == null) {
      return const LoadingState(label: 'Loading asset profile…');
    }
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    final loans = data.loans.where((l) => l.assetId == asset.id).toList();
    final approvals = data.approvals
        .where((a) => a.assetId == asset.id)
        .toList();
    final audit = data.audit.where((a) => a.recordId == asset.id).toList();
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASSET PROFILE',
              style: monoStyle(context, size: 9, color: context.colors.accent),
            ),
            Text(asset.id, style: monoStyle(context, size: 15)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Close profile',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                asset.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusBadge.asset(asset.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${asset.manufacturer} / ${asset.partNumber} / ${asset.equipmentType}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 540;
                            final photo = Stack(
                              children: [
                                AssetPhoto(
                                  url: asset.photoUrl,
                                  label: asset.description,
                                  width: double.infinity,
                                  height: 260,
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _uploading
                                        ? null
                                        : () => _uploadPhoto(asset),
                                    icon: _uploading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.upload_file,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _uploading
                                          ? 'UPLOADING'
                                          : 'REPLACE PHOTO',
                                    ),
                                  ),
                                ),
                              ],
                            );
                            final qr = Container(
                              height: 260,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.colors.elevated,
                                border: Border.all(
                                  color: context.colors.border,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: QrImageView(
                                      data: asset.id,
                                      backgroundColor: context.colors.sidebar,
                                      eyeStyle: QrEyeStyle(
                                        color: context.colors.textPrimary,
                                      ),
                                      dataModuleStyle: QrDataModuleStyle(
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    asset.id,
                                    style: monoStyle(context, size: 10),
                                  ),
                                ],
                              ),
                            );
                            if (narrow) {
                              return Column(
                                children: [
                                  photo,
                                  const SizedBox(height: 12),
                                  qr,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: photo,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(width: 180, child: qr),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i < 2 ? 8 : 0,
                                  ),
                                  child: AssetPhoto(
                                    url: asset.photoUrl,
                                    label: [
                                      'REGISTER VIEW',
                                      'INSPECTION VIEW',
                                      'LOCATION VIEW',
                                    ][i],
                                    height: 62,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (index, label) in [
                                'SPECIFICATIONS',
                                'FINANCE & PROCUREMENT',
                                'HISTORY & AUDIT',
                              ].indexed) ...[
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _tab == index,
                                  onSelected: (_) =>
                                      setState(() => _tab = index),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: switch (_tab) {
                      0 => _specifications(asset),
                      1 => _finance(asset, user, money),
                      _ => _history(
                        loans.length,
                        approvals.length,
                        audit.length,
                        data,
                        asset,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specifications(ToolAsset asset) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PrecisionPanel(
        title: 'IDENTIFICATION / LEGACY MAPPING',
        child: Column(
          children: [
            KeyValueRow(
              label: 'Serial number',
              value: asset.serialNumber,
              mono: true,
            ),
            KeyValueRow(
              label: 'Part number',
              value: asset.partNumber,
              mono: true,
            ),
            KeyValueRow(label: 'Series', value: asset.series),
            KeyValueRow(
              label: 'Quantity / physical units',
              value: '${asset.quantity} / 1 unique asset ID',
            ),
            KeyValueRow(
              label: 'Legacy Type 1',
              value: asset.legacyTypePrimary,
              mono: true,
            ),
            KeyValueRow(
              label: 'Legacy Type 2',
              value: asset.legacyTypeSecondary,
              mono: true,
            ),
            KeyValueRow(
              label: 'Legacy depreciation A',
              value: asset.legacyDepreciationPrimary.toStringAsFixed(2),
              mono: true,
            ),
            KeyValueRow(
              label: 'Legacy depreciation B',
              value: asset.legacyDepreciationSecondary.toStringAsFixed(2),
              mono: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      PrecisionPanel(
        title: 'LOCATION / OPERATIONS',
        child: Column(
          children: [
            KeyValueRow(label: 'Project / department', value: asset.department),
            KeyValueRow(
              label: 'Department code',
              value: asset.departmentCode,
              mono: true,
            ),
            KeyValueRow(label: 'Lying at', value: asset.lyingAt),
            KeyValueRow(label: 'Condition', value: asset.condition),
            KeyValueRow(
              label: 'Issued to',
              value: asset.issuedTo.isEmpty ? '—' : asset.issuedTo,
            ),
            KeyValueRow(
              label: 'Transferred to',
              value: asset.transferredTo.isEmpty ? '—' : asset.transferredTo,
            ),
            KeyValueRow(
              label: 'Current borrower',
              value: asset.currentBorrower.isEmpty
                  ? '—'
                  : asset.currentBorrower,
            ),
            KeyValueRow(
              label: 'Expected return',
              value: asset.expectedReturnDate == null
                  ? '—'
                  : DateFormat('dd MMM yyyy • HH:mm')
                        .format(asset.expectedReturnDate!),
              mono: true,
            ),
            KeyValueRow(label: 'Purpose', value: asset.purpose),
            KeyValueRow(label: 'Remarks', value: asset.remarks),
          ],
        ),
      ),
    ],
  );

  Widget _finance(ToolAsset asset, AppUser user, NumberFormat money) {
    if (user.role != UserRole.manager) {
      return const EmptyState(
        title: 'Financial data restricted',
        message: 'Lender accounts can inspect operational asset details but not financial valuation or procurement records.',
      );
    }
    return Column(
      children: [
        if (asset.financialReviewRequired)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.warning),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: context.colors.warning),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Historical spreadsheet depreciation differs from the configured policy. Source values are preserved; manager review is required.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        PrecisionPanel(
          title: 'FINANCIAL VALUATION',
          child: Column(
            children: [
              KeyValueRow(
                label: 'Unit price',
                value: money.format(asset.unitPricePkr),
                mono: true,
              ),
              KeyValueRow(
                label: 'Extended price',
                value: money.format(asset.extendedPricePkr),
                mono: true,
              ),
              KeyValueRow(
                label: 'Historical GST',
                value:
                    '${money.format(asset.historicalGstAmountPkr)} @ ${(asset.historicalGstRate * 100).toStringAsFixed(0)}%',
              ),
              KeyValueRow(
                label: 'Total purchase value',
                value: money.format(asset.totalPurchaseValuePkr),
                mono: true,
              ),
              KeyValueRow(
                label: 'Foreign value',
                value:
                    '${asset.foreignCurrencyCode} ${asset.foreignCurrencyValue.toStringAsFixed(2)}',
                mono: true,
              ),
              KeyValueRow(
                label: 'Purchase / valuation',
                value:
                    '${DateFormat('dd MMM yyyy').format(asset.purchaseDate)} / ${DateFormat('dd MMM yyyy').format(asset.valuationDate)}',
              ),
              KeyValueRow(
                label: 'Days since purchase',
                value: '${asset.daysSincePurchase}',
                mono: true,
              ),
              KeyValueRow(
                label: 'Useful life',
                value: '${asset.usefulLifeYears} years',
              ),
              KeyValueRow(
                label: 'Daily depreciation',
                value: money.format(asset.dailyDepreciation),
                mono: true,
              ),
              KeyValueRow(
                label: 'Accumulated depreciation',
                value: money.format(asset.accumulatedDepreciation),
                mono: true,
              ),
              KeyValueRow(
                label: 'Net book value',
                value: money.format(asset.netBookValue),
                mono: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrecisionPanel(
          title: 'PROCUREMENT',
          child: Column(
            children: [
              KeyValueRow(label: 'Vendor', value: asset.vendor),
              KeyValueRow(
                label: 'Source',
                value: asset.isImported ? 'Imported' : 'Local',
              ),
              KeyValueRow(
                label: 'OES purchase order',
                value: asset.oesPurchaseOrder,
                mono: true,
              ),
              KeyValueRow(
                label: 'Bill number',
                value: asset.billNumber,
                mono: true,
              ),
              KeyValueRow(
                label: 'Bill date',
                value: DateFormat('dd MMM yyyy').format(asset.billDate),
                mono: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _history(
    int loanCount,
    int approvalCount,
    int auditCount,
    dynamic data,
    ToolAsset asset,
  ) {
    final loans = data.loans.where((l) => l.assetId == asset.id).toList();
    final approvals = data.approvals
        .where((a) => a.assetId == asset.id)
        .toList();
    final audits = data.audit.where((a) => a.recordId == asset.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrecisionPanel(
          title: 'LENDING HISTORY',
          code: '$loanCount RECORDS',
          child: loans.isEmpty
              ? const Text('No lending transactions recorded.')
              : Column(
                  children: loans
                      .map<Widget>(
                        (l) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.borrowerName),
                          subtitle: Text(
                            '${l.workOrder} • ${DateFormat('dd MMM yyyy').format(l.issueDate)}',
                          ),
                          trailing: StatusBadge.loan(l.status),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        PrecisionPanel(
          title: 'MAINTENANCE & APPROVALS',
          code: '$approvalCount REQUESTS',
          child: Column(
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.build_outlined),
                title: Text('Preventive inspection'),
                subtitle: Text(
                  'No open maintenance work orders in mock history.',
                ),
              ),
              ...approvals.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.typeLabel),
                  subtitle: Text(a.reason),
                  trailing: StatusBadge.approval(a.status),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrecisionPanel(
          title: 'IMMUTABLE AUDIT TIMELINE',
          code: '$auditCount EVENTS',
          child: audits.isEmpty
              ? const Text(
                  'No asset-specific events in the current mock audit window.',
                )
              : Column(
                  children: audits
                      .map<Widget>(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.circle,
                            size: 8,
                            color: context.colors.accent,
                          ),
                          title: Text(a.action),
                          subtitle: Text(
                            '${a.actor} • ${a.details}\n${DateFormat('dd MMM yyyy HH:mm:ss').format(a.timestamp)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
