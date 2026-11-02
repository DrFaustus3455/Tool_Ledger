import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../inventory/data/models/tool_asset.dart';

class QrLabelStudio extends ConsumerStatefulWidget {
  const QrLabelStudio({super.key});
  @override
  ConsumerState<QrLabelStudio> createState() => _QrLabelStudioState();
}

class _QrLabelStudioState extends ConsumerState<QrLabelStudio> {
  final Set<String> _selected = {};
  var _width = 70.0;
  var _height = 40.0;
  var _printing = false;

  Future<void> _print(List<ToolAsset> assets) async {
    if (assets.isEmpty) {
      showAppSnackBar(
        context,
        'Select at least one asset for batch generation.',
        error: true,
      );
      return;
    }
    setState(() => _printing = true);
    try {
      final doc = pw.Document();
      for (final asset in assets) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              _width * PdfPageFormat.mm,
              _height * PdfPageFormat.mm,
              marginAll: 3 * PdfPageFormat.mm,
            ),
            build: (context) => pw.Row(
              children: [
                pw.Container(
                  width: 29 * PdfPageFormat.mm,
                  height: 29 * PdfPageFormat.mm,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: asset.id,
                  ),
                ),
                pw.SizedBox(width: 3 * PdfPageFormat.mm),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 16 * PdfPageFormat.mm,
                        padding: const pw.EdgeInsets.symmetric(vertical: 1),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: .6),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'OES LOGO',
                          style: const pw.TextStyle(fontSize: 5),
                        ),
                      ),
                      pw.SizedBox(height: 2 * PdfPageFormat.mm),
                      pw.Text(
                        asset.description,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
                      pw.Text(asset.id, style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(
                        asset.equipmentType.toUpperCase(),
                        style: const pw.TextStyle(fontSize: 5.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'ToolLedger_QR_labels_${_width.toInt()}x${_height.toInt()}mm.pdf',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Label generation failed: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) {
        final selectedAssets = data.assets
            .where((a) => _selected.contains(a.id))
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'QR label studio',
                    subtitle: 'Print or batch-generate labels without changing the original equipment identifier.',
                    eyebrow: 'IDENTITY / NO FINANCIAL OR PERSONAL DATA',
                    actions: [
                      FilledButton.icon(
                        onPressed: _printing
                            ? null
                            : () => _print(selectedAssets),
                        icon: _printing
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(
                          _printing ? 'GENERATING…' : 'PRINT / SAVE LABELS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 900;
                      final selection = PrecisionPanel(
                        title: 'BATCH ASSET SELECTION',
                        code: '${_selected.length} SELECTED',
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _selected.addAll(
                                        data.assets.map((a) => a.id),
                                      ),
                                    ),
                                    child: const Text('Select all'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _selected.clear()),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                            ...data.assets.map(
                              (asset) => CheckboxListTile(
                                value: _selected.contains(asset.id),
                                onChanged: (v) => setState(
                                  () => v == true
                                      ? _selected.add(asset.id)
                                      : _selected.remove(asset.id),
                                ),
                                title: Text(asset.description),
                                subtitle: Text(
                                  '${asset.id} • ${asset.equipmentType}',
                                  style: monoStyle(context, size: 9),
                                ),
                                secondary: const Icon(Icons.qr_code_2),
                              ),
                            ),
                          ],
                        ),
                      );
                      final preview = Column(
                        children: [
                          PrecisionPanel(
                            title: 'LABEL SETTINGS',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<double>(
                                  initialValue: _width,
                                  decoration: const InputDecoration(
                                    labelText: 'Label size',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 50,
                                      child: Text('50 × 30 mm'),
                                    ),
                                    DropdownMenuItem(
                                      value: 70,
                                      child: Text('70 × 40 mm'),
                                    ),
                                    DropdownMenuItem(
                                      value: 100,
                                      child: Text('100 × 60 mm'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _width = v!;
                                    _height = v == 50
                                        ? 30
                                        : v == 70
                                        ? 40
                                        : 60;
                                  }),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Each PDF page uses the selected physical dimensions. Reprinting always reuses the same asset ID; no new identity is issued.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrecisionPanel(
                            title: 'LIVE LABEL PREVIEW',
                            code: selectedAssets.isEmpty
                                ? 'NO SELECTION'
                                : '${selectedAssets.length} LABELS',
                            child: selectedAssets.isEmpty
                                ? const EmptyState(
                                    title: 'Select equipment',
                                    message: 'Choose one or more assets to preview and generate labels.',
                                  )
                                : Column(
                                    children: selectedAssets
                                        .take(4)
                                        .map(
                                          (asset) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: context.colors.sidebar,
                                              border: Border.all(
                                                color:
                                                    context.colors.textPrimary,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                            child: Row(
                                              children: [
                                                QrImageView(
                                                  data: asset.id,
                                                  size: 104,
                                                  backgroundColor:
                                                      context.colors.sidebar,
                                                  eyeStyle: QrEyeStyle(
                                                    color: context
                                                        .colors
                                                        .textPrimary,
                                                  ),
                                                  dataModuleStyle:
                                                      QrDataModuleStyle(
                                                        color: context
                                                            .colors
                                                            .textPrimary,
                                                      ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              3,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: context
                                                                .colors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'OES LOGO',
                                                          style: monoStyle(
                                                            context,
                                                            size: 7,
                                                            color: context
                                                                .colors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        asset.description,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall,
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        asset.id,
                                                        style: monoStyle(
                                                          context,
                                                          size: 10,
                                                        ),
                                                      ),
                                                      Text(
                                                        asset.equipmentType
                                                            .toUpperCase(),
                                                        style: monoStyle(
                                                          context,
                                                          size: 8,
                                                          color: context
                                                              .colors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            preview,
                            const SizedBox(height: 16),
                            selection,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: selection),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: preview),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
