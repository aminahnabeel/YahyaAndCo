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

  /// Optional background gradient (overrides backgroundColor when provided)
  final Gradient? gradient;

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
    this.gradient,
    this.textColor,
    this.elevation,
    this.loadingColor,
    this.padding,
    this.letterSpacing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderR = BorderRadius.circular(borderRadius ?? 12);

    // If a gradient is provided, render a decorated InkWell to show gradient
    if (gradient != null) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height ?? 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: borderR,
            boxShadow: [
              if ((elevation ?? 2) > 0)
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: (elevation ?? 2) * 4,
                  offset: Offset(0, (elevation ?? 2)),
                )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderR,
              onTap: (isLoading || !enabled) ? null : onPressed,
              child: Center(
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
                              letterSpacing: letterSpacing ?? 0.3,
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
                          letterSpacing: letterSpacing ?? 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    // Fallback: normal ElevatedButton
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: (isLoading || !enabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          elevation: elevation ?? 2,
          shadowColor:
              (backgroundColor ?? AppColors.primary).withOpacity(0.25),

          // Better spacing inside button
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

          // Square / rounded rectangle shape
          shape: RoundedRectangleBorder(
            borderRadius: borderR,
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
                      letterSpacing: letterSpacing ?? 0.3,
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
                  letterSpacing: letterSpacing ?? 0.3,
                ),
              ),
      ),
    );
  }
}