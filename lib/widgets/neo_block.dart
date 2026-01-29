import 'package:flutter/material.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

class NeoBlock extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const NeoBlock({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.margin,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 2.5, // Thick border
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor ?? AppColors.border,
            offset: shadowOffset, // Hard shadow
            blurRadius: 0, // No blur
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2), // Inner clipping
        child: Padding(
          padding: padding ?? const EdgeInsets.all(0),
          child: child,
        ),
      ),
    );
  }
}
