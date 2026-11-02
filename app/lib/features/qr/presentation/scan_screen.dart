import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/asset_photo.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../data/qr_asset_reference.dart';
import '../../inventory/presentation/asset_profile.dart';
import '../../loans/presentation/checkout_dialog.dart';
import '../../loans/presentation/damage_dialog.dart';
import '../../loans/presentation/return_dialog.dart';

enum ScanMode { issue, returnAsset, damage }

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.initialMode = ScanMode.issue});
  final ScanMode initialMode;
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _manual = TextEditingController();
  final _scanner = MobileScannerController();
  late final AnimationController _animation;
  late ScanMode _mode;
  ToolAsset? _asset;
  var _camera = true;
  final _processing = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _animation.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _manual.dispose();
    _scanner.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_processing || _asset != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) _lookup(code);
  }

  void _lookup(String code) {
    final id = QrAssetReference.normalize(code);
    final data = ref.read(workspaceProvider).value;
    final asset = data?.assetById(id);
    if (asset == null) {
      showAppSnackBar(
        context,
        'No registered asset matches "$id". Check the label or register the equipment.',
        error: true,
      );
      setState(() => _asset = null);
      return;
    }
    setState(() => _asset = asset);
  }

  void _continue() {
    final asset = _asset;
    if (asset == null) return;
    switch (_mode) {
      case ScanMode.issue:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => CheckoutDialog(asset: asset),
        );
      case ScanMode.returnAsset:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ReturnDialog(asset: asset),
        );
      case ScanMode.damage:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => DamageDialog(asset: asset),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    if (_asset != null && data != null) _asset = data.assetById(_asset!.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'QR equipment operations',
                subtitle: 'Verify the physical asset before every issue, return or damage report.',
                eyebrow: 'SCAN / VERIFY / CONFIRM',
                actions: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _asset = null;
                      _manual.clear();
                    }),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset scan'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<ScanMode>(
                segments: const [
                  ButtonSegment(
                    value: ScanMode.issue,
                    icon: Icon(Icons.output),
                    label: Text('ISSUE TOOL'),
                  ),
                  ButtonSegment(
                    value: ScanMode.returnAsset,
                    icon: Icon(Icons.input),
                    label: Text('RECEIVE RETURN'),
                  ),
                  ButtonSegment(
                    value: ScanMode.damage,
                    icon: Icon(Icons.report_problem_outlined),
                    label: Text('REPORT DAMAGE'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() {
                  _mode = v.first;
                  _asset = null;
                }),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 850;
                  final scanner = _scannerPanel();
                  final verification = _verificationPanel();
                  if (!wide) {
                    return Column(
                      children: [
                        scanner,
                        const SizedBox(height: 16),
                        verification,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: scanner),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: verification),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.usb, color: context.colors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'USB scanners work through the focused manual field. Production handover authorization and availability are always rechecked by the backend immediately before issue.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scannerPanel() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'CAMERA SCANNER',
                style: monoStyle(
                  context,
                  size: 10,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _camera = !_camera),
              child: Text(_camera ? 'Hide camera' : 'Use camera'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: context.colors.background),
                if (_camera && _asset == null)
                  MobileScanner(
                    controller: _scanner,
                    onDetect: _detect,
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_photography_outlined,
                              color: context.colors.warning,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera unavailable or permission denied',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use manual asset ID or a keyboard-emulating USB scanner.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_camera || _asset != null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _asset == null
                              ? Icons.videocam_off_outlined
                              : Icons.check_circle_outline,
                          size: 48,
                          color: context.colors.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _asset == null ? 'Camera paused' : 'Asset captured',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                CustomPaint(painter: _ScannerCorners(context.colors.accent)),
                if (_camera && _asset == null)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) => Positioned(
                      left: 32,
                      right: 32,
                      top: 30 + _animation.value * (220),
                      child: Container(height: 1, color: context.colors.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'MANUAL / USB ASSET ENTRY',
          style: monoStyle(
            context,
            size: 9,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manual,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _lookup,
                decoration: const InputDecoration(
                  hintText: 'e.g. TL-TORQ-001',
                  prefixIcon: Icon(Icons.keyboard_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => _lookup(_manual.text),
              child: const Text('VERIFY'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _verificationPanel() {
    final asset = _asset;
    if (asset == null) {
      return Container(
        height: 360,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 54,
              color: context.colors.textSecondary,
            ),
            const SizedBox(height: 18),
            Text(
              'Awaiting asset identity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'The scanned identifier contains no financial or personal data.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    final isValid = switch (_mode) {
      ScanMode.issue => asset.isLendable,
      ScanMode.returnAsset =>
        asset.status == AssetStatus.checkedOut ||
            asset.status == AssetStatus.overdue,
      ScanMode.damage => asset.status != AssetStatus.retired,
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(
          color: isValid ? context.colors.accent : context.colors.danger,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ASSET VERIFICATION',
                  style: monoStyle(
                    context,
                    size: 10,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              StatusBadge.asset(asset.status, compact: true),
            ],
          ),
          const SizedBox(height: 14),
          AssetPhoto(
            url: asset.photoUrl,
            label: asset.description,
            width: double.infinity,
            height: 150,
          ),
          const SizedBox(height: 14),
          Text(
            asset.id,
            style: monoStyle(context, size: 11, color: context.colors.accent),
          ),
          const SizedBox(height: 6),
          Text(
            asset.description,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${asset.manufacturer} • ${asset.equipmentType}\n${asset.condition}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!isValid) ...[
            const SizedBox(height: 12),
            Text(
              _mode == ScanMode.issue
                  ? 'Issue blocked: asset is not available and serviceable.'
                  : _mode == ScanMode.returnAsset
                  ? 'No active checkout state to return.'
                  : 'Disposed assets cannot receive new damage reports.',
              style: TextStyle(color: context.colors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showAssetProfile(context, asset.id),
                  child: const Text('Inspect profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isValid ? _continue : null,
                  child: Text(switch (_mode) {
                    ScanMode.issue => 'CONTINUE ISSUE',
                    ScanMode.returnAsset => 'INSPECT RETURN',
                    ScanMode.damage => 'REPORT DAMAGE',
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerCorners extends CustomPainter {
  const _ScannerCorners(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const l = 38.0;
    const inset = 24.0;
    final points = [
      [
        Offset(inset, inset + l),
        Offset(inset, inset),
        Offset(inset + l, inset),
      ],
      [
        Offset(size.width - inset - l, inset),
        Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + l),
      ],
      [
        Offset(inset, size.height - inset - l),
        Offset(inset, size.height - inset),
        Offset(inset + l, size.height - inset),
      ],
      [
        Offset(size.width - inset - l, size.height - inset),
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - l),
      ],
    ];
    for (final path in points) {
      canvas.drawPath(
        Path()
          ..moveTo(path[0].dx, path[0].dy)
          ..lineTo(path[1].dx, path[1].dy)
          ..lineTo(path[2].dx, path[2].dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ScannerCorners old) => old.color != color;
}
