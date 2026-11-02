import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: monoStyle(
                context,
                size: 10,
                color: context.colors.accent,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      );
      if (constraints.maxWidth < 700 && actions.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            copy,
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: copy),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 20),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      );
    },
  );
}
