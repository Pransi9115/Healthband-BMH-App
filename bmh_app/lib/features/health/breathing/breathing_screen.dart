import 'package:flutter/material.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';

// ─────────────────────────────────────────────────────────
//  BREATHING SCREEN
//  Guided breathing exercise for stress relief
// ─────────────────────────────────────────────────────────
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isRunning = false;
  String _phase = 'Tap to Start';
  int _cycleCount = 0;

  // 4-7-8 breathing pattern (seconds)
  static const _inhale  = 4;
  static const _hold    = 7;
  static const _exhale  = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _inhale + _hold + _exhale));
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.addStatusListener(_onStatus);
    _controller.addListener(_onTick);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _cycleCount++;
      if (_isRunning) _controller.forward(from: 0);
    }
  }

  void _onTick() {
    if (!mounted) return;
    final t = _controller.value * (_inhale + _hold + _exhale);
    String phase;
    if (t < _inhale) phase = 'Inhale...';
    else if (t < _inhale + _hold) phase = 'Hold...';
    else phase = 'Exhale...';
    if (phase != _phase) setState(() => _phase = phase);
  }

  void _toggle() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
      _phase = 'Tap to Start';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: BMHColors.line)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: BMHColors.ink))),
        title: Text('Breathing Exercise',
          style: BMHText.heading2.copyWith(fontSize: 16))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated circle
            GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => Container(
                  width: 200 * _animation.value,
                  height: 200 * _animation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      BMHColors.sOxygen.withOpacity(0.5),
                      BMHColors.sOxygen.withOpacity(0.1),
                    ]),
                    border: Border.all(
                      color: BMHColors.sOxygen.withOpacity(0.6),
                      width: 2)),
                  child: Center(
                    child: Text(_phase,
                      textAlign: TextAlign.center,
                      style: BMHText.heading2.copyWith(
                        color: BMHColors.ink, fontSize: 18)))))),
            const SizedBox(height: 40),
            Text('4 · 7 · 8 Breathing',
              style: BMHText.monoSm.copyWith(
                color: BMHColors.inkMute, fontSize: 11)),
            const SizedBox(height: 8),
            Text('Cycles completed: $_cycleCount',
              style: BMHText.monoSm.copyWith(
                color: BMHColors.sOxygen, fontSize: 11)),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Column(children: [
                _PhaseRow('Inhale', '$_inhale sec', BMHColors.sOxygen),
                const SizedBox(height: 8),
                _PhaseRow('Hold', '$_hold sec', BMHColors.sGut),
                const SizedBox(height: 8),
                _PhaseRow('Exhale', '$_exhale sec', BMHColors.sCardio),
              ])),
          ])),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label, duration;
  final Color color;
  const _PhaseRow(this.label, this.duration, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: BMHText.bodyMd),
      ]),
      Text(duration, style: BMHText.monoSm.copyWith(color: color)),
    ]);
}
