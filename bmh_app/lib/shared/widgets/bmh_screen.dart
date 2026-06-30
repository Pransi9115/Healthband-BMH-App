// ─────────────────────────────────────────────────────────
//  BMH SHARED SCREEN COMPONENTS
//  Single source of truth for layout used on EVERY screen
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/bmh_tokens.dart';
import 'bmh_widgets.dart';

// ── STANDARD SCREEN BACKGROUND ───────────────────────────
// Every screen uses this — deep navy + ambient top glow

class BMHScreenBackground extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final AlignmentGeometry glowAlignment;

  const BMHScreenBackground({
    super.key,
    required this.child,
    this.glowColor = BMHColors.cyan,
    this.glowAlignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(
        children: [
          // Ambient radial glow — top
          Positioned(
            top: -180,
            left: glowAlignment == Alignment.topLeft ? -120 : null,
            right: glowAlignment == Alignment.topRight ? -120 : null,
            child: Container(
              width: 480, height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  glowColor.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Bottom opposite glow
          Positioned(
            bottom: -120,
            right: glowAlignment == Alignment.topLeft ? -80 : null,
            left: glowAlignment == Alignment.topRight ? -80 : null,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  BMHColors.sOxygen.withOpacity(0.04),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── STANDARD TOP BAR WITH BACK BUTTON ────────────────────
// Used by Sign In, Sign Up, OTP, Forgot Password,
// BLE screens, Health detail, etc.

class BMHTopBar extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  const BMHTopBar({
    super.key,
    this.eyebrow,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BMHSpacing.screenH, 8, BMHSpacing.screenH, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + trailing row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showBack)
                BMHIconButton(
                  onTap: onBack ?? () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: BMHColors.ink, size: 16,
                  ),
                )
              else
                const SizedBox(width: 38),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 28),
          // Eyebrow
          if (eyebrow != null) ...[
            BMHEyebrow(eyebrow!, showDot: true),
            const SizedBox(height: 10),
          ],
          // Title
          Text(title, style: BMHText.heading1),
        ],
      ),
    );
  }
}

// ── STANDARD TEXT INPUT ───────────────────────────────────
// Used on Sign In, Sign Up, Forgot Password — identical style

class BMHInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const BMHInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: BMHText.monoMd.copyWith(
            color: BMHColors.inkDim,
            fontSize: 10,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        // Field
        Container(
          decoration: BoxDecoration(
            color: BMHColors.bg3,
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(color: BMHColors.line),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            focusNode: focusNode,
            maxLength: maxLength,
            onChanged: onChanged,
            style: BMHText.bodyMd.copyWith(color: BMHColors.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: BMHText.bodyMd.copyWith(color: BMHColors.inkMute),
              counterText: '',
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: prefixIcon,
                    )
                  : null,
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: suffixIcon,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BMHRadius.md),
                borderSide: const BorderSide(
                  color: BMHColors.cyan, width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16,
              ),
              filled: false,
            ),
          ),
        ),
      ],
    );
  }
}

// ── PRIMARY BUTTON LOADING STATE ─────────────────────────

class BMHButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final Color? color;

  const BMHButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? BMHColors.cyan,
          foregroundColor: BMHColors.bg0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BMHRadius.full),
          ),
          elevation: 0,
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  color: BMHColors.bg0,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: BMHText.labelLg.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: BMHColors.bg0,
                ),
              ),
      ),
    );
  }
}

// ── HERO TITLE BLOCK ─────────────────────────────────────
// "Create account" / "Sign in" etc — Fraunces with italic cyan

class BMHHeroTitle extends StatelessWidget {
  final String line1;
  final String line2;

  const BMHHeroTitle({
    super.key,
    required this.line1,
    required this.line2,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: BMHText.displayMd.copyWith(fontSize: 34, height: 1.2),
        children: [
          TextSpan(text: '$line1\n'),
          TextSpan(
            text: line2,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: BMHColors.cyan,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
