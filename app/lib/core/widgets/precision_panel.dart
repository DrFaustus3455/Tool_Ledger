import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PrecisionPanel extends StatelessWidget {
  const PrecisionPanel({
    super.key,
    required this.child,
    this.title,
    this.code,
    this.padding = const EdgeInsets.all(20),
    this.trailing,
  });
  final Widget child;
  final String? title;
  final String? code;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.colors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: monoStyle(
                      context,
                      size: 11,
                      color: context.colors.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                if (code != null)
                  Text(
                    code!,
                    style: monoStyle(
                      context,
                      size: 9,
                      color: context.colors.accent,
                    ),
                  ),
                ?trailing,
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),
        ],
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
  });
  final String label;
  final String value;
  final bool mono;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            style: mono
                ? monoStyle(context)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
