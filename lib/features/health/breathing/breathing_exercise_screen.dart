import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import 'breathing_screen.dart';

// ─────────────────────────────────────────────────────────
//  BREATHING EXERCISE SCREEN
// ─────────────────────────────────────────────────────────
class BreathingExerciseScreen extends StatefulWidget {
  final BreathingProgram program;
  final int durationMinutes;
  const BreathingExerciseScreen({
    super.key, required this.program, required this.durationMinutes});
  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {

  // Animation controllers
  late AnimationController _circleCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _circleAnim;
  late Animation<double> _glowAnim;

  // Phase tracking
  int _phaseIndex  = 0;
  int _phaseSecond = 0;
  int _totalSeconds = 0;
  int _cyclesCompleted = 0;

  // State
  bool _isRunning = false;
  bool _isPaused  = false;
  bool _isDone    = false;
  bool _haptic    = true;

  Timer? _timer;

  int get _totalDuration => widget.durationMinutes * 60;
  int get _remaining => _totalDuration - _totalSeconds;
  BreathingPhase get _currentPhase =>
      widget.program.phases[_phaseIndex];

  @override
  void initState() {
    super.initState();

    _circleCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4));
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _circleAnim = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(
          parent: _circleCtrl, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(
          parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _circleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _start() {
    setState(() { _isRunning = true; _isPaused = false; });
    _runPhase();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _totalSeconds++;
        _phaseSecond++;
        if (_phaseSecond >= _currentPhase.seconds) {
          _advancePhase();
        }
        if (_totalSeconds >= _totalDuration) {
          _complete();
        }
      });
    });
  }

  void _runPhase() {
    final phase = _currentPhase;
    _circleCtrl.duration = Duration(seconds: phase.seconds);
    if (_haptic) HapticFeedback.lightImpact();
    if (phase.expand) {
      _circleCtrl.forward(from: 0);
    } else {
      _circleCtrl.reverse(from: 1);
    }
  }

  void _advancePhase() {
    _phaseSecond = 0;
    _phaseIndex = (_phaseIndex + 1) % widget.program.phases.length;
    if (_phaseIndex == 0) _cyclesCompleted++;
    _runPhase();
  }

  void _pause() {
    _timer?.cancel();
    _circleCtrl.stop();
    setState(() { _isPaused = true; _isRunning = false; });
  }

  void _resume() {
    setState(() { _isPaused = false; _isRunning = true; });
    _start();
  }

  void _stop() {
    _timer?.cancel();
    _circleCtrl.stop();
    _circleCtrl.value = 0.55;
    setState(() {
      _isRunning = false; _isPaused = false;
      _phaseIndex = 0; _phaseSecond = 0;
      _totalSeconds = 0; _cyclesCompleted = 0;
    });
  }

  void _complete() {
    _timer?.cancel();
    _circleCtrl.stop();
    if (_haptic) HapticFeedback.heavyImpact();
    setState(() { _isDone = true; _isRunning = false; });
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    if (_isDone) return _CompletionScreen(
      program: widget.program,
      durationMinutes: widget.durationMinutes,
      cycles: _cyclesCompleted,
      onRepeat: () { setState(() { _isDone = false; _totalSeconds = 0; _cyclesCompleted = 0; }); _start(); },
      onDone: () => Navigator.pop(context));

    final phase = _currentPhase;
    final p = widget.program;
    final phaseProgress = _currentPhase.seconds > 0
        ? _phaseSecond / _currentPhase.seconds : 0.0;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        // Background glow
        AnimatedBuilder(animation: _glowAnim, builder: (_, __) =>
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                p.color.withOpacity(_glowAnim.value * 0.08),
                Colors.transparent]))))),
        SafeArea(bottom: false,
          child: Column(children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH, vertical: 8),
              child: Row(children: [
                BMHIconButton(
                  onTap: () { _stop(); Navigator.pop(context); },
                  icon: const Icon(Icons.close_rounded,
                    color: BMHColors.ink, size: 18)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BMHEyebrow(p.emoji + ' ' + p.name),
                  Text('Breathing Exercise', style: BMHText.heading2),
                ])),
                // Haptic toggle
                GestureDetector(
                  onTap: () => setState(() => _haptic = !_haptic),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _haptic
                          ? p.color.withOpacity(0.12) : BMHColors.bg4,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _haptic
                          ? p.color.withOpacity(0.3) : BMHColors.line)),
                    child: Icon(Icons.vibration_rounded,
                      color: _haptic ? p.color : BMHColors.inkMute,
                      size: 16))),
              ])),

            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Session timer
                Text(_formatTime(_remaining),
                  style: BMHText.monoLg.copyWith(
                    color: BMHColors.inkDim, fontSize: 14)),
                const SizedBox(height: 40),

                // BREATHING CIRCLE
                _BreathingCircle(
                  animation: _circleAnim,
                  glowAnim: _glowAnim,
                  ringProgress: phaseProgress,
                  color: p.color,
                  phase: phase,
                  phaseSecond: _phaseSecond,
                  isRunning: _isRunning,
                  isPaused: _isPaused),

                const SizedBox(height: 40),

                // Phase instruction
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _isPaused ? 'Paused'
                        : _isRunning ? phase.label : 'Ready',
                    key: ValueKey(_isPaused ? 'paused' : phase.label),
                    style: BMHText.displayMd.copyWith(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      color: _isPaused ? BMHColors.inkMute : p.color,
                      fontSize: 28))),

                const SizedBox(height: 8),

                // Countdown
                if (_isRunning)
                  Text(
                    '${_currentPhase.seconds - _phaseSecond}',
                    style: BMHText.monoLg.copyWith(
                      fontSize: 48, color: p.color.withOpacity(0.4),
                      height: 1)),

                const SizedBox(height: 8),
                Text('Cycle ${_cyclesCompleted + 1}',
                  style: BMHText.monoSm.copyWith(color: BMHColors.inkMute)),
              ])),

            // CONTROLS
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BMHSpacing.screenH, 0, BMHSpacing.screenH, 48),
              child: Column(children: [
                // Phase indicators
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.program.phases.length, (i) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _phaseIndex ? 24 : 8,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _phaseIndex
                            ? p.color : p.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2))))),
                const SizedBox(height: 24),
                // Buttons
                if (!_isRunning && !_isPaused)
                  SizedBox(width: double.infinity, height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.color,
                        foregroundColor: BMHColors.bg0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BMHRadius.full)),
                        elevation: 0),
                      onPressed: _start,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.play_arrow_rounded, size: 24),
                        const SizedBox(width: 8),
                        Text('Start Breathing',
                          style: BMHText.labelLg.copyWith(
                            color: BMHColors.bg0,
                            fontWeight: FontWeight.w600)),
                      ])))
                else
                  Row(children: [
                    // Pause / Resume
                    Expanded(child: SizedBox(height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPaused
                              ? p.color : BMHColors.bg3,
                          foregroundColor: _isPaused
                              ? BMHColors.bg0 : BMHColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BMHRadius.full),
                            side: BorderSide(color: _isPaused
                                ? p.color : BMHColors.line)),
                          elevation: 0),
                        onPressed: _isPaused ? _resume : _pause,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(_isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded, size: 22),
                          const SizedBox(width: 6),
                          Text(_isPaused ? 'Resume' : 'Pause',
                            style: BMHText.labelLg),
                        ])))),
                    const SizedBox(width: 12),
                    // Stop
                    SizedBox(height: 56, width: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BMHColors.danger.withOpacity(0.1),
                          foregroundColor: BMHColors.danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BMHRadius.full),
                            side: BorderSide(
                              color: BMHColors.danger.withOpacity(0.3))),
                          elevation: 0, padding: EdgeInsets.zero),
                        onPressed: _stop,
                        child: const Icon(Icons.stop_rounded, size: 22))),
                  ]),
              ])),
          ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  BREATHING CIRCLE WIDGET
// ─────────────────────────────────────────────────────────
class _BreathingCircle extends StatelessWidget {
  final Animation<double> animation, glowAnim;
  final double ringProgress;
  final Color color;
  final BreathingPhase phase;
  final int phaseSecond;
  final bool isRunning, isPaused;

  const _BreathingCircle({
    required this.animation, required this.glowAnim,
    required this.ringProgress, required this.color,
    required this.phase, required this.phaseSecond,
    required this.isRunning, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, glowAnim]),
      builder: (_, __) {
        final size = 200.0;
        final scale = isRunning ? animation.value : 0.55;
        return SizedBox(width: size + 60, height: size + 60,
          child: CustomPaint(
            painter: _BreathingPainter(
              progress: ringProgress,
              color: color, glowOpacity: glowAnim.value),
            child: Center(child: AnimatedContainer(
              duration: Duration(
                milliseconds: phase.seconds * 100),
              curve: Curves.easeInOut,
              width: size * scale,
              height: size * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  color.withOpacity(0.5),
                  color.withOpacity(0.15)]),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(glowAnim.value * 0.6),
                    blurRadius: 40, spreadRadius: 5)]),
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                if (isPaused)
                  const Icon(Icons.pause_rounded,
                    color: Colors.white70, size: 32)
                else if (!isRunning)
                  const Icon(Icons.air_rounded,
                    color: Colors.white70, size: 32)
                else
                  Text('${phase.seconds - phaseSecond}',
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 36, color: Colors.white,
                      fontWeight: FontWeight.w300, height: 1)),
              ])))),
        ));
      });
  }
}

// ─────────────────────────────────────────────────────────
//  CLOCK RING PAINTER
// ─────────────────────────────────────────────────────────
class _BreathingPainter extends CustomPainter {
  final double progress, glowOpacity;
  final Color color;
  const _BreathingPainter({
    required this.progress, required this.color,
    required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progPaint);

    // Glow dots at ring end
    if (progress > 0.01) {
      final dotAngle = -math.pi / 2 + sweepAngle;
      final dotPos = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle));
      final dotPaint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(dotPos, 6, dotPaint);
      canvas.drawCircle(dotPos, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BreathingPainter old) =>
      old.progress != progress || old.glowOpacity != glowOpacity;
}

// ─────────────────────────────────────────────────────────
//  COMPLETION SCREEN
// ─────────────────────────────────────────────────────────
class _CompletionScreen extends StatefulWidget {
  final BreathingProgram program;
  final int durationMinutes, cycles;
  final VoidCallback onRepeat, onDone;
  const _CompletionScreen({
    required this.program, required this.durationMinutes,
    required this.cycles, required this.onRepeat, required this.onDone});
  @override
  State<_CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<_CompletionScreen> {
  String? _mood;
  final _moods = [
    ('Calmer', '😌'), ('More Focused', '🎯'),
    ('Sleepier', '😴'), ('Less Anxious', '🧘'),
    ('No Change', '😐'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -100, left: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                p.color.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(children: [
              const SizedBox(height: 40),
              // ✅ Icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.color.withOpacity(0.12),
                  border: Border.all(
                    color: p.color.withOpacity(0.3), width: 2),
                  boxShadow: [BoxShadow(
                    color: p.color.withOpacity(0.3),
                    blurRadius: 30, spreadRadius: 5)]),
                child: Center(child: Text('✅',
                  style: const TextStyle(fontSize: 36)))),
              const SizedBox(height: 24),
              Text('Session Complete',
                style: BMHText.displayMd.copyWith(
                  fontFamily: 'Fraunces', fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                'You completed a ${widget.durationMinutes}-minute\n${p.name} session.',
                textAlign: TextAlign.center,
                style: BMHText.bodyMd.copyWith(color: BMHColors.inkDim)),
              const SizedBox(height: 8),
              Text(
                'Your breathing session may help support relaxation,\nnervous system balance, and stress recovery.',
                textAlign: TextAlign.center,
                style: BMHText.bodySm.copyWith(
                  fontStyle: FontStyle.italic, color: BMHColors.inkMute)),
              const SizedBox(height: 28),
              // Stats row
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: p.color.withOpacity(0.2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                  _StatCell('Duration', '${widget.durationMinutes} min',
                    p.color),
                  _StatCell('Cycles', '${widget.cycles}', p.color),
                  _StatCell('Program', p.name.split(' ').first, p.color),
                ])),
              const SizedBox(height: 28),
              // Mood check
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('How do you feel now?', style: BMHText.heading2),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _moods.map((m) {
                      final selected = _mood == m.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _mood = m.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? p.color.withOpacity(0.15) : BMHColors.bg4,
                            borderRadius: BorderRadius.circular(
                              BMHRadius.full),
                            border: Border.all(
                              color: selected
                                  ? p.color : BMHColors.line)),
                          child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                            Text(m.$2),
                            const SizedBox(width: 6),
                            Text(m.$1,
                              style: BMHText.monoSm.copyWith(
                                color: selected
                                    ? p.color : BMHColors.inkMute,
                                fontWeight: selected
                                    ? FontWeight.w600 : FontWeight.w400)),
                          ])));
                    }).toList()),
                ])),
              const SizedBox(height: 28),
              // Buttons
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.color,
                    foregroundColor: BMHColors.bg0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    elevation: 0),
                  onPressed: widget.onRepeat,
                  child: Text('Repeat Session',
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.bg0,
                      fontWeight: FontWeight.w600)))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: BMHColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BMHRadius.full))),
                  onPressed: widget.onDone,
                  child: Text('Back to Dashboard',
                    style: BMHText.labelLg))),
              const SizedBox(height: 120),
            ]))),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value; final Color color;
  const _StatCell(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: BMHText.displaySm.copyWith(
      fontSize: 22, color: color, height: 1)),
    const SizedBox(height: 4),
    Text(label, style: BMHText.monoSm.copyWith(fontSize: 9)),
  ]);
}
