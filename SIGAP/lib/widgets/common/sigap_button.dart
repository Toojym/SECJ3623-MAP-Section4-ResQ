import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

enum SigapButtonVariant { primary, danger, outlined, ghost }

class SigapButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final SigapButtonVariant variant;
  final Widget? icon;
  final double? width;
  final double height;

  const SigapButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = SigapButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (variant) {
      case SigapButtonVariant.danger:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _buildChild(Colors.white),
        );
      case SigapButtonVariant.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(AppColors.primary),
        );
      case SigapButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(AppColors.primary),
        );
      case SigapButtonVariant.primary:
        return Container(
          decoration: BoxDecoration(
            gradient: isLoading || onPressed == null ? null : AppColors.primaryGradient,
            color: isLoading || onPressed == null ? AppColors.border : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _buildChild(Colors.white),
          ),
        );
    }
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == SigapButtonVariant.primary || variant == SigapButtonVariant.danger
              ? Colors.white
              : AppColors.primary,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
