import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.warning,
    required this.danger,
    required this.border,
    required this.grid,
    required this.info,
  });

  final Color background;
  final Color sidebar;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color warning;
  final Color danger;
  final Color border;
  final Color grid;
  final Color info;

  static const dark = AppColors(
    background: Color(0xFF101820),
    sidebar: Color(0xFF131E27),
    surface: Color(0xFF1C2B35),
    elevated: Color(0xFF253743),
    textPrimary: Color(0xFFE9E8E0),
    textSecondary: Color(0xFFA5B2BB),
    accent: Color(0xFF29D6B0),
    warning: Color(0xFFFFB454),
    danger: Color(0xFFF26B6B),
    border: Color(0xFF334751),
    grid: Color(0xFF21333D),
    info: Color(0xFF73B8D4),
  );

  static const light = AppColors(
    background: Color(0xFFF4F6F5),
    sidebar: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFE8EFEE),
    textPrimary: Color(0xFF182831),
    textSecondary: Color(0xFF65747B),
    accent: Color(0xFF087F70),
    warning: Color(0xFFA7650B),
    danger: Color(0xFFBD3545),
    border: Color(0xFFD5DEDC),
    grid: Color(0xFFE6ECEA),
    info: Color(0xFF356E88),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? sidebar,
    Color? surface,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? warning,
    Color? danger,
    Color? border,
    Color? grid,
    Color? info,
  }) => AppColors(
    background: background ?? this.background,
    sidebar: sidebar ?? this.sidebar,
    surface: surface ?? this.surface,
    elevated: elevated ?? this.elevated,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    accent: accent ?? this.accent,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    border: border ?? this.border,
    grid: grid ?? this.grid,
    info: info ?? this.info,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      border: Color.lerp(border, other.border, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension AppColorContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
