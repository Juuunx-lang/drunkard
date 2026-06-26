import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class NeonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  const NeonText({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.color = BarColors.neonPink,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        shadows: [
          Shadow(color: color.withOpacity(0.8), blurRadius: 8),
          Shadow(color: color.withOpacity(0.4), blurRadius: 16),
          Shadow(color: color.withOpacity(0.2), blurRadius: 32),
        ],
      ),
    );
  }
}
