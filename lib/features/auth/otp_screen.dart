import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import '../home/main_shell.dart';
import '../../core/auth/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _secs = 60;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nodes[0].requestFocus(),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secs = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secs == 0) { t.cancel(); return; }
      setState(() => _secs--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrl) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrl.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() => _loading = true);

    // TODO(api): verify OTP against your backend; on success save
    // the real tokens returned by the server.
    await Future.delayed(const Duration(milliseconds: 1400));
    await AuthService.instance.saveSession(
      accessToken: 'local-session-${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
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

              const BMHEyebrow('Verification', showDot: true),
              const SizedBox(height: 10),
              const BMHHeroTitle(line1: 'Enter', line2: 'OTP code'),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to\n${widget.email}',
                style: BMHText.italic,
              ),

              const SizedBox(height: 44),

              // ── OTP BOXES ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrl[i],
                  focusNode: _nodes[i],
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                    setState(() {});
                    if (_otp.length == 6) _verify();
                  },
                )),
              ),

              const SizedBox(height: 40),

              BMHButton(
                label: 'Verify & Continue',
                loading: _loading,
                onTap: _otp.length == 6 ? _verify : null,
              ),

              const SizedBox(height: 28),

              Center(
                child: _secs > 0
                    ? Text.rich(TextSpan(children: [
                        TextSpan(text: 'Resend code in ',
                          style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
                        TextSpan(text: '${_secs}s',
                          style: BMHText.monoMd.copyWith(color: BMHColors.cyan)),
                      ]))
                    : GestureDetector(
                        onTap: _startTimer,
                        child: Text('Resend code',
                          style: BMHText.labelMd.copyWith(color: BMHColors.cyan)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: BMHText.displaySm.copyWith(
          fontSize: 22, color: BMHColors.cyan,
          fontFamily: 'Plus Jakarta Sans',
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: BMHColors.bg3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BMHRadius.md),
            borderSide: const BorderSide(color: BMHColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BMHRadius.md),
            borderSide: const BorderSide(color: BMHColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BMHRadius.md),
            borderSide: const BorderSide(color: BMHColors.cyan, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
