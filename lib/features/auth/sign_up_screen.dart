import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import 'otp_screen.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _consent = false;
  int _step = 0;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0) { setState(() => _step = 1); return; }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => OtpScreen(email: _emailCtrl.text)));
  }

  @override
  Widget build(BuildContext context) {
    return BMHScreenBackground(
      glowColor: BMHColors.cyan,
      glowAlignment: Alignment.topLeft,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              BMHIconButton(
                onTap: () {
                  if (_step == 1) setState(() => _step = 0);
                  else Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16),
              ),
              const SizedBox(height: 28),

              // Step indicator
              Row(children: [
                _StepDot(active: _step >= 0, done: false, label: '1'),
                _StepLine(active: _step >= 1),
                _StepDot(active: _step >= 1, done: false, label: '2'),
                _StepLine(active: false),
                _StepDot(active: false, done: false, label: '3'),
              ]),
              const SizedBox(height: 28),

              BMHEyebrow(
                _step == 0 ? 'Step 1 of 3 — Your details' : 'Step 2 of 3 — Security',
                showDot: true,
              ),
              const SizedBox(height: 10),
              BMHHeroTitle(
                line1: 'Create',
                line2: _step == 0 ? 'account' : 'password',
              ),
              const SizedBox(height: 36),

              // Step 0
              if (_step == 0) ...[
                BMHInput(
                  controller: _nameCtrl,
                  label: 'FULL NAME',
                  hint: 'Your full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                    color: BMHColors.inkMute, size: 18),
                ),
                const SizedBox(height: 18),
                BMHInput(
                  controller: _emailCtrl,
                  label: 'EMAIL ADDRESS',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline_rounded,
                    color: BMHColors.inkMute, size: 18),
                ),
              ],

              // Step 1
              if (_step == 1) ...[
                BMHInput(
                  controller: _passCtrl,
                  label: 'PASSWORD',
                  hint: 'Min 8 characters',
                  obscure: _obscure,
                  onChanged: (_) => setState(() {}),
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: BMHColors.inkMute, size: 18),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: BMHColors.inkMute, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                _StrengthBar(password: _passCtrl.text),
                const SizedBox(height: 20),
                // Consent
                GestureDetector(
                  onTap: () => setState(() => _consent = !_consent),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _consent ? BMHColors.cyan : BMHColors.bg4,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _consent ? BMHColors.cyan : BMHColors.line),
                        ),
                        child: _consent
                            ? const Icon(Icons.check_rounded,
                                color: BMHColors.bg0, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I agree to the processing of my health data for personalised insights (GDPR special category data).',
                          style: BMHText.bodySm.copyWith(color: BMHColors.inkDim),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),
              BMHButton(
                label: _step == 0 ? 'Continue' : 'Create Account',
                loading: _loading,
                onTap: _next,
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const SignInScreen())),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Already have an account? ',
                      style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
                    TextSpan(text: 'Sign In',
                      style: BMHText.bodySm.copyWith(
                        color: BMHColors.cyan, fontWeight: FontWeight.w600)),
                  ])),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Step indicator widgets
class _StepDot extends StatelessWidget {
  final bool active, done;
  final String label;
  const _StepDot({required this.active, required this.done, required this.label});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: active ? BMHColors.cyan : BMHColors.bg4,
        shape: BoxShape.circle,
        border: Border.all(color: active ? BMHColors.cyan : BMHColors.line),
        boxShadow: active ? BMHShadows.cyan : [],
      ),
      child: Center(
        child: Text(label, style: BMHText.monoSm.copyWith(
          color: active ? BMHColors.bg0 : BMHColors.inkMute,
          fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});
  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 1,
      color: active ? BMHColors.cyan : BMHColors.line,
    ),
  );
}

class _StrengthBar extends StatelessWidget {
  final String password;
  const _StrengthBar({required this.password});

  int get _score {
    if (password.length < 4) return 0;
    if (password.length < 8) return 1;
    int s = 2;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    return s.clamp(0, 4);
  }

  Color get _color => [
    BMHColors.danger, BMHColors.sNervous,
    BMHColors.sMetabolic, BMHColors.sGut, BMHColors.cyan,
  ][_score];

  String get _label =>
      ['Too short', 'Weak', 'Fair', 'Good', 'Strong'][_score];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: List.generate(4, (i) => Expanded(
        child: Container(
          height: 3,
          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
          decoration: BoxDecoration(
            color: i < _score ? _color : BMHColors.bg4,
            borderRadius: BorderRadius.circular(2)),
        ),
      ))),
      const SizedBox(height: 5),
      Text(_label, style: BMHText.monoSm.copyWith(color: _color, fontSize: 10)),
    ],
  );
}
