import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BMHScreenBackground(
      glowColor: BMHColors.cyan,
      glowAlignment: Alignment.topLeft,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // ── LOGO MARK ─────────────────────────
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      color: BMHColors.bg1,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BMHColors.lineBright),
                      boxShadow: BMHShadows.cyan,
                    ),
                    child: const Center(
                      child: BMHScanLineFigure(
                        width: 36, height: 54, opacity: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand name
                  Text(
                    'BIO MEDICAL',
                    style: BMHText.eyebrow.copyWith(
                      fontSize: 10, letterSpacing: 0.42 * 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'HEALTHCARE',
                    style: BMHText.labelLg.copyWith(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.14 * 20,
                      color: BMHColors.ink,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── HERO TEXT ─────────────────────────
                  Text.rich(
                    TextSpan(
                      style: BMHText.displayLg.copyWith(
                        fontSize: 36, height: 1.2,
                      ),
                      children: const [
                        TextSpan(text: 'Your biology,\n'),
                        TextSpan(
                          text: 'listening.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: BMHColors.cyan,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Monitor 40+ health signals in real time.\nClinically reviewed. Always with you.',
                    style: BMHText.italic.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── FEATURE DOTS ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot('Health Band'),
                      _Divider(),
                      _Dot('BioScale'),
                      _Divider(),
                      _Dot('24/7 Monitor'),
                    ],
                  ),

                  const Spacer(),

                  // ── SIGN IN BUTTON ────────────────────
                  BMHButton(
                    label: 'Sign In',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignInScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── CREATE ACCOUNT ────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BMHColors.cyan,
                        side: const BorderSide(color: BMHColors.cyan),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BMHRadius.full),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: BMHText.labelLg.copyWith(
                          color: BMHColors.cyan, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Legal note
                  Text(
                    'By continuing you agree to our Terms & Privacy Policy',
                    style: BMHText.monoSm.copyWith(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  const _Dot(this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BMHPulsingDot(size: 5),
      const SizedBox(width: 5),
      Text(label, style: BMHText.monoSm.copyWith(fontSize: 9)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: BMHColors.line,
  );
}
