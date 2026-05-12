import 'package:flutter/material.dart';

import '../theme.dart';

class CustomButton extends StatefulWidget {
  /// The text to display on the button
  final String text;

  /// Callback function when button is pressed
  final VoidCallback onPressed;

  /// Whether the button is in a loading state
  final bool isLoading;

  /// Optional custom width (defaults to 54)
  final double? width;

  /// Optional custom height (defaults to 54)
  final double? height;

  /// Optional custom border radius (defaults to 32)
  final double? borderRadius;

  /// Optional custom font size (defaults to 16)
  final double? fontSize;

  /// Optional custom font weight (defaults to w700)
  final FontWeight? fontWeight;

  /// Optional custom background color (defaults to primary blue)
  final Color? backgroundColor;

  /// Optional custom text color (defaults to white)
  final Color? textColor;

  /// Optional custom elevation/shadow (defaults to 4)
  final double? elevation;

  /// Optional loading indicator color
  final Color? loadingColor;

  /// Optional custom padding
  final EdgeInsets? padding;

  /// Optional letter spacing
  final double? letterSpacing;

  /// Is the button disabled
  final bool enabled;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.borderRadius,
    this.fontSize,
    this.fontWeight,
    this.backgroundColor,
    this.textColor,
    this.elevation,
    this.loadingColor,
    this.padding,
    this.letterSpacing,
    this.enabled = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 54,
      height: widget.height ?? 54,
      child: ElevatedButton(
        onPressed: (widget.isLoading || !widget.enabled) ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor ?? AppColors.primary,
          foregroundColor: widget.textColor ?? Colors.white,
          elevation: widget.elevation ?? 4,
          shadowColor: (widget.backgroundColor ?? AppColors.primary).withOpacity(0.5),
          padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 32),
          ),
          disabledBackgroundColor: (widget.backgroundColor ?? AppColors.primary).withOpacity(0.6),
          disabledForegroundColor: (widget.textColor ?? Colors.white).withOpacity(0.6),
        ),
        child: widget.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: widget.loadingColor ?? Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: widget.fontSize ?? 16,
                      fontWeight: widget.fontWeight ?? FontWeight.w700,
                      color: widget.textColor ?? Colors.white,
                      letterSpacing: widget.letterSpacing ?? 0.4,
                    ),
                  ),
                ],
              )
            : Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.fontSize ?? 16,
                  fontWeight: widget.fontWeight ?? FontWeight.w700,
                  color: widget.textColor ?? Colors.white,
                  letterSpacing: widget.letterSpacing ?? 0.4,
                ),
              ),
      ),
    );
  }
}
