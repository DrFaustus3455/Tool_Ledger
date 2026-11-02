import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/security/security_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/data/models/tool_asset.dart';

class DamageDialog extends ConsumerStatefulWidget {
  const DamageDialog({super.key, required this.asset});
  final ToolAsset asset;
  @override
  ConsumerState<DamageDialog> createState() => _DamageDialogState();
}

class _DamageDialogState extends ConsumerState<DamageDialog> {
  final _notes = TextEditingController();
  final List<XFile> _photos = [];
  var _loading = false;
  var _complete = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    for (final file in await ImagePicker().pickMultiImage(
      maxWidth: 2200,
      maxHeight: 2200,
    )) {
      final bytes = await file.readAsBytes();
      if (!SecurityPolicy.isAllowedImage(file.name, bytes.length)) {
        if (mounted) {
          showAppSnackBar(
            context,
            '${file.name}: invalid type or larger than 5 MB.',
            error: true,
          );
        }
        continue;
      }
      if (_photos.length < 6) setState(() => _photos.add(file));
    }
  }

  Future<void> _submit() async {
    if (_notes.text.trim().length < 10) {
      setState(() => _error = 'Provide a detailed damage description.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(workspaceProvider.notifier)
          .reportDamage(
            widget.asset.id,
            _notes.text.trim(),
            ref.read(sessionProvider).user!,
            _photos.length,
          );
      if (mounted) setState(() => _complete = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _complete ? 'Damage record created' : 'Report equipment damage',
    ),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: _complete
            ? Column(
                children: [
                  Icon(
                    Icons.report_problem_outlined,
                    size: 56,
                    color: context.colors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.asset.id} is DAMAGED',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The asset has been removed from active lending inventory and added to the damaged register with its financial history.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.asset.description),
                    subtitle: Text(
                      '${widget.asset.id} • ${widget.asset.manufacturer}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notes,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Damage description',
                      hintText: 'What happened, visible defects, affected accessories, safety implications…',
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add evidence photographs'),
                  ),
                  if (_photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _photos
                            .map(
                              (f) => InputChip(
                                label: Text(f.name),
                                onDeleted: () =>
                                    setState(() => _photos.remove(f)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Up to 6 JPG/PNG images, 5 MB each. Production files require private backend-authorized storage and server MIME validation.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 14),
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
      if (!_complete)
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: const Text('SUBMIT DAMAGE REPORT'),
        ),
    ],
  );
}
