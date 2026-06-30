import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => OtpScreen(email: _ctrl.text)));
  }

  @override
  Widget build(BuildContext context) {
    return BMHScreenBackground(
      glowColor: BMHColors.cyan,
      glowAlignment: Alignment.topLeft,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16),
              ),
              const SizedBox(height: 36),
              const BMHEyebrow('Account recovery', showDot: true),
              const SizedBox(height: 10),
              const BMHHeroTitle(line1: 'Reset', line2: 'password'),
              const SizedBox(height: 10),
              Text('Enter your email and we\'ll send a reset code.',
                style: BMHText.italic),
              const SizedBox(height: 40),
              BMHInput(
                controller: _ctrl,
                label: 'EMAIL ADDRESS',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline_rounded,
                  color: BMHColors.inkMute, size: 18),
              ),
              const SizedBox(height: 36),
              BMHButton(
                label: 'Send Reset Code',
                loading: _loading,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
