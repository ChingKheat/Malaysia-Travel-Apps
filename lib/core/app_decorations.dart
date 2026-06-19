import 'package:flutter/material.dart';

import 'app_colors.dart';

BoxDecoration cardDecoration([Color color = Colors.white]) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: color == Colors.white ? AppColors.line : Colors.transparent,
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x0D111827), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}
