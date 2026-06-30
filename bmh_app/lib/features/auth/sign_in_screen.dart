import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import '../home/main_shell.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BMHScreenBackground(
      glowColor: BMHColors.cyan,
      glowAlignment: Alignment.topRight,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── BACK ──────────────────────────────────
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16),
              ),

              const SizedBox(height: 36),

              // ── HEADER ────────────────────────────────
              const BMHEyebrow('Welcome back', showDot: true),
              const SizedBox(height: 10),
              const BMHHeroTitle(line1: 'Sign', line2: 'in'),
              const SizedBox(height: 8),
              Text(
                'Your biology has been waiting.',
                style: BMHText.italic,
              ),

              const SizedBox(height: 40),

              // ── EMAIL ─────────────────────────────────
              BMHInput(
                controller: _emailCtrl,
                label: 'EMAIL ADDRESS',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline_rounded,
                  color: BMHColors.inkMute, size: 18),
              ),

              const SizedBox(height: 18),

              // ── PASSWORD ──────────────────────────────
              BMHInput(
                controller: _passCtrl,
                label: 'PASSWORD',
                hint: '••••••••',
                obscure: _obscure,
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: BMHColors.inkMute, size: 18),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: BMHColors.inkMute, size: 18,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Forgot
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen())),
                  child: Text(
                    'Forgot password?',
                    style: BMHText.monoMd.copyWith(
                      color: BMHColors.cyan, fontSize: 11),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── SIGN IN ───────────────────────────────
              BMHButton(
                label: 'Sign In',
                loading: _loading,
                onTap: _signIn,
              ),

              const SizedBox(height: 24),

              // Divider
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: BMHText.monoSm),
                ),
                const Expanded(child: Divider()),
              ]),

              const SizedBox(height: 24),

              // Create account
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BMHColors.cyan,
                    side: const BorderSide(color: BMHColors.cyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                  ),
                  onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: Text('Create Account',
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.cyan, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 40),

              // Brand quote
              Center(
                child: Text(
                  '"The future doesn\'t have to be unpredictable."',
                  style: BMHText.italic.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
