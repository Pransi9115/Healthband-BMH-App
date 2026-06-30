import 'package:flutter/material.dart';
import 'dart:async';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import 'breathing_program.dart';
import 'breathing_completion_screen.dart';

// ─────────────────────────────────────────────────────────
//  BREATHING SESSION SCREEN - FIXED VERSION
//  Active breathing exercise with animations & timer
//  
//  FIXES APPLIED:
//  ✅ Fix #1: Auto-completion navigates to Results
//  ✅ Fix #2: Resume button works with proper animation state
//  ✅ Fix #4: Timing uses real elapsed time, not animation value
//  ✅ Fix #5: Clear labeling of phase countdown
// ─────────────────────────────────────────────────────────

class BreathingSessionScreen extends StatefulWidget {
  final BreathingSession session;
  const BreathingSessionScreen({super.key, required this.session});

  @override
  State<BreathingSessionScreen> createState() => _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Timer _timer;
  late Timer _updateTimer;
  bool _isRunning = false;
  bool _isPaused = false;
  String _currentPhase = 'Ready';
  int _phaseCountdown = 0;
  int _cyclesCompleted = 0;

  @override
  void initState() {
    super.initState();
    final program = BreathingProgram.getById(widget.session.programId);
    _setupAnimation(program);
    _startTimers();
  }

  void _setupAnimation(BreathingProgram program) {
    final duration = Duration(seconds: program.cycleDurationSeconds);
    _animationController = AnimationController(vsync: this, duration: duration);
    _animationController.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_isRunning && !widget.session.isComplete) {
        _cyclesCompleted++;
        widget.session.cyclesCompleted = _cyclesCompleted;
        _animationController.forward(from: 0);
      }
    }
  }

  void _startTimers() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _updatePhase();
      });

      // ✅ FIX #1: Check if session is complete and navigate to Results
      if (widget.session.isComplete && _isRunning) {
        _stopSession();  // Navigate to Results instead of just pausing
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  // ✅ FIX #4: Use real elapsed time instead of animation controller value
  void _updatePhase() {
    final program = BreathingProgram.getById(widget.session.programId);
    
    // Calculate which part of the cycle we're in based on REAL elapsed time
    final elapsedInCurrentCycle = widget.session.elapsedSeconds % program.cycleDurationSeconds;

    String phase;
    int countdown;

    // Determine phase based on real elapsed time in this cycle
    if (elapsedInCurrentCycle < program.inhaleSeconds) {
      phase = 'Inhale';
      countdown = (program.inhaleSeconds - elapsedInCurrentCycle).ceil();
    } else if (elapsedInCurrentCycle < program.inhaleSeconds + program.holdSeconds) {
      phase = 'Hold';
      countdown = (program.inhaleSeconds + program.holdSeconds - elapsedInCurrentCycle).ceil();
    } else if (elapsedInCurrentCycle < program.inhaleSeconds + program.holdSeconds + program.exhaleSeconds) {
      phase = 'Exhale';
      countdown = (program.inhaleSeconds + program.holdSeconds + program.exhaleSeconds - elapsedInCurrentCycle).ceil();
    } else {
      phase = 'Rest';
      countdown = (program.cycleDurationSeconds - elapsedInCurrentCycle).ceil();
    }

    _currentPhase = phase;
    _phaseCountdown = countdown.clamp(0, 99);
    
    // Also sync animation to real time for smooth visual
    final normalizedPosition = elapsedInCurrentCycle / program.cycleDurationSeconds;
    if (_isRunning && !_isPaused) {
      _animationController.animateTo(
        normalizedPosition.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  void _toggleSession() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        final program = BreathingProgram.getById(widget.session.programId);
        final elapsedInCycle = widget.session.elapsedSeconds % program.cycleDurationSeconds;
        final normalizedPos = elapsedInCycle / program.cycleDurationSeconds;
        _animationController.animateTo(normalizedPos, duration: const Duration(milliseconds: 100));
      } else {
        _animationController.stop();
      }
    });
  }

  void _pauseSession() {
    setState(() {
      _isRunning = false;
      _isPaused = true;
      _animationController.stop();
    });
  }

  // ✅ FIX #2: Resume with proper animation state continuation
  void _resumeSession() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
      final program = BreathingProgram.getById(widget.session.programId);
      final elapsedInCycle = widget.session.elapsedSeconds % program.cycleDurationSeconds;
      final normalizedPos = elapsedInCycle / program.cycleDurationSeconds;
      
      // Continue animation from current position
      _animationController.animateTo(
        normalizedPos.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 100),
      );
    });
  }

  void _stopSession() {
    _pauseSession();
    widget.session.endTime = DateTime.now();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BreathingCompletionScreen(
          session: widget.session,
          cyclesCompleted: _cyclesCompleted,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer.cancel();
    _updateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = BreathingProgram.getById(widget.session.programId);
    final elapsed = widget.session.elapsedSeconds;
    final remaining = widget.session.remainingSeconds;
    final progress = widget.session.progressPercent;

    final elapsedMin = elapsed ~/ 60;
    final elapsedSec = elapsed % 60;
    final remainingMin = remaining ~/ 60;
    final remainingSec = remaining % 60;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: _stopSession,
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: BMHColors.line),
            ),
            child: const Icon(Icons.close_rounded, size: 14, color: BMHColors.ink),
          ),
        ),
        title: Text('💨 ${program.name}',
          style: BMHText.heading2.copyWith(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Session Timer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Elapsed', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        const SizedBox(height: 4),
                        Text('$elapsedMin:${elapsedSec.toString().padLeft(2, '0')}',
                          style: BMHText.bodyLg.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: BMHColors.line),
                    Column(
                      children: [
                        Text('Remaining', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        const SizedBox(height: 4),
                        Text('$remainingMin:${remainingSec.toString().padLeft(2, '0')}',
                          style: BMHText.bodyLg.copyWith(color: BMHColors.sCardio)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Animated Circle with Countdown
              SizedBox(
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress Ring
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: _ProgressRingPainter(progress: progress),
                    ),
                    
                    // Animated Breathing Circle
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final t = _animationController.value;
                        // Scale from 0.6 to 1.0 and back
                        double scale = 0.6 + (t * 0.4);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  BMHColors.sOxygen.withOpacity(0.4),
                                  BMHColors.sOxygen.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                color: BMHColors.sOxygen.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_phaseCountdown.toString(),
                                    style: BMHText.displaySm.copyWith(
                                      color: BMHColors.cyan,
                                      fontSize: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // ✅ FIX #5: Clear label for phase countdown
                                  Text(_currentPhase,
                                    style: BMHText.bodyMd.copyWith(color: BMHColors.ink2),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('sec',
                                    style: BMHText.bodySm.copyWith(color: BMHColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Session Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cycles Completed', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text('$_cyclesCompleted / ${program.getCyclesForDuration(widget.session.durationMinutes)}',
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text('$progress%',
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isRunning && !_isPaused)
                    GestureDetector(
                      onTap: _toggleSession,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        decoration: BoxDecoration(
                          color: BMHColors.cyan,
                          borderRadius: BorderRadius.circular(BMHRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: BMHColors.bg0, size: 20),
                            const SizedBox(width: 8),
                            Text('Start', style: BMHText.bodyMd.copyWith(
                              color: BMHColors.bg0,
                              fontWeight: FontWeight.w600,
                            )),
                          ],
                        ),
                      ),
                    ),
                  if (_isRunning)
                    GestureDetector(
                      onTap: _pauseSession,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        decoration: BoxDecoration(
                          color: BMHColors.sCardio,
                          borderRadius: BorderRadius.circular(BMHRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pause_rounded, color: BMHColors.bg0, size: 20),
                            const SizedBox(width: 8),
                            Text('Pause', style: BMHText.bodyMd.copyWith(
                              color: BMHColors.bg0,
                              fontWeight: FontWeight.w600,
                            )),
                          ],
                        ),
                      ),
                    ),
                  if (_isPaused)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _resumeSession,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: BMHColors.cyan,
                              borderRadius: BorderRadius.circular(BMHRadius.md),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: BMHColors.bg0, size: 20),
                                const SizedBox(width: 8),
                                Text('Resume', style: BMHText.bodyMd.copyWith(
                                  color: BMHColors.bg0,
                                  fontWeight: FontWeight.w600,
                                )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _stopSession,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: BMHColors.surface,
                              borderRadius: BorderRadius.circular(BMHRadius.md),
                              border: Border.all(color: BMHColors.line),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stop_rounded, color: BMHColors.sCardio, size: 20),
                                const SizedBox(width: 8),
                                Text('Stop', style: BMHText.bodyMd.copyWith(
                                  color: BMHColors.sCardio,
                                  fontWeight: FontWeight.w600,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final int progress; // 0-100

  _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = BMHColors.bg2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Progress arc
    final sweepAngle = (progress / 100) * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      Paint()
        ..color = BMHColors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
