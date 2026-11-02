import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AssetPhoto extends StatelessWidget {
  const AssetPhoto({
    super.key,
    this.url,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final String label;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(label: label, width: width, height: height);
    if (url == null || url!.isEmpty) return fallback;
    if (url!.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(url!.split(',').last),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    if (url!.startsWith('assets/')) {
      return Image.asset(
        url!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label, this.width, this.height});
  final String label;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    color: context.colors.elevated,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.precision_manufacturing_outlined,
          color: context.colors.accent,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: monoStyle(
            context,
            size: 10,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
