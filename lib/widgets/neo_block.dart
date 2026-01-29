import 'package:flutter/material.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

class NeoBlock extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? stdShadows; // Custom shadows for Standard mode

  const NeoBlock({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderRadius = 12.0,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.margin,
    this.stdShadows,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the current theme implies a border (Neo style)
    final themeShape =
        Theme.of(context).cardTheme.shape as RoundedRectangleBorder?;
    final hasBorder =
        themeShape?.side.width != null && (themeShape!.side.width > 0);

    // If explicit properties (borderColor) are passed, we respect them.
    // Otherwise, we adapt to the theme.

    final effectiveBorderColor =
        borderColor ?? ((hasBorder) ? AppColors.border : Colors.transparent);
    final effectiveBorderWidth = (hasBorder) ? 2.5 : 0.0;

    // Neo Shadow (Hard, Offset) vs Standard Shadow (Soft, Blur)
    // We simulate Standard shadow with BoxShadow if not in Neo mode
    final List<BoxShadow> effectiveShadows = hasBorder
        ? [
            // Neo Shadow
            BoxShadow(
              color: AppColors.border,
              offset: shadowOffset,
              blurRadius: 0,
            ),
          ]
        : (stdShadows ??
              [
                // Standard Soft Shadow (Default)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  offset: const Offset(0, 4),
                  blurRadius: 20,
                ),
              ]);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
        ),
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          borderRadius - effectiveBorderWidth,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(0),
          child: child,
        ),
      ),
    );
  }
}
