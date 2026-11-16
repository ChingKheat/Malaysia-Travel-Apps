import 'package:flutter/material.dart';

import 'app_colors.dart';

BoxDecoration cardDecoration([
  Color color = AppColors.nightSurface,
  Color? borderColor,
]) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: borderColor ??
          (color == AppColors.nightAccentContainer
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.line),
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x0D111827), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}
