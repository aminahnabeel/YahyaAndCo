import 'package:flutter/material.dart';

import '../theme.dart';

class CustomButton extends StatelessWidget {
  /// The text to display on the button
  final String text;

  /// Callback function when button is pressed
  final VoidCallback onPressed;

  /// Whether the button is in a loading state
  final bool isLoading;

  /// Optional custom width
  final double? width;

  /// Optional custom height
  final double? height;

  /// Optional custom border radius
  final double? borderRadius;

  /// Optional custom font size
  final double? fontSize;

  /// Optional custom font weight
  final FontWeight? fontWeight;

  /// Optional custom background color
  final Color? backgroundColor;

  /// Optional custom text color
  final Color? textColor;

  /// Optional custom elevation/shadow
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 54,
      child: ElevatedButton(
        onPressed: (isLoading || !enabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          elevation: elevation ?? 4,
          shadowColor:
              (backgroundColor ?? AppColors.primary).withOpacity(0.18),

          // Better spacing inside button
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),

          // Square / rounded rectangle shape
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6),
          ),

          disabledBackgroundColor:
              (backgroundColor ?? AppColors.primary).withOpacity(0.6),

          disabledForegroundColor:
              (textColor ?? Colors.white).withOpacity(0.7),
        ),

        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: loadingColor ?? Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: fontSize ?? 16,
                      fontWeight: fontWeight ?? FontWeight.w600,
                      color: textColor ?? Colors.white,
                      letterSpacing: letterSpacing ?? 0.4,
                    ),
                  ),
                ],
              )
            : Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize ?? 16,
                  fontWeight: fontWeight ?? FontWeight.w600,
                  color: textColor ?? Colors.white,
                  letterSpacing: letterSpacing ?? 0.4,
                ),
              ),
      ),
    );
  }
}