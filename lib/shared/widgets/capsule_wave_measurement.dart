import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/bmh_tokens.dart';

/// ─────────────────────────────────────────────────────────
///  CAPSULE WAVE MEASUREMENT — reusable for every metric.
///
///  • One component for HR, HRV, SpO₂, BP, temperature,
///    glucose (only if hardware supports it) and steps sync.
///  • The wave is NOT a timer — completion is driven only by
///    the device SDK via `state`. Pass progress/seconds only
///    when the SDK genuinely reports them.
///  • Honours Reduce Motion (MediaQuery.disableAnimations):
///    continuous wave is replaced by a slow level change and
///    a pulsing three-dot indicator.
///  • Haptics: soft on start, success/warning/error per state.
/// ─────────────────────────────────────────────────────────

enum MeasurementType {
  heartRate, heartRateVariability, spo2, bloodPressure,
  skinTemperature, glucose, steps,
}

enum MeasurementState {
  preparing, measuring, processing, success, failed,
  cancelled, deviceDisconnected,
}

class MeasurementTypeConfig {
  final String title;
  final IconData icon;
  final Color color;
  final String unit;
  final String instruction;
  final int? expectedSeconds; // null = SDK gives no reliable duration
  const MeasurementTypeConfig({
    required this.title, required this.icon, required this.color,
    required this.unit, required this.instruction, this.expectedSeconds,
  });

  static MeasurementTypeConfig of(MeasurementType t) {
    switch (t) {
      case MeasurementType.heartRate:
        return const MeasurementTypeConfig(
          title: 'Heart Rate Measurement', icon: Icons.favorite_rounded,
          color: Color(0xFFFF5577), unit: 'bpm',
          instruction: 'Please remain still and keep the band fitted securely.',
          expectedSeconds: 30);
      case MeasurementType.heartRateVariability:
        return const MeasurementTypeConfig(
          title: 'HRV Measurement', icon: Icons.monitor_heart_rounded,
          color: Color(0xFF8B5CF6), unit: 'ms',
          instruction: 'Please remain still and keep the band fitted securely.',
          expectedSeconds: 60);
      case MeasurementType.spo2:
        return const MeasurementTypeConfig(
          title: 'SpO₂ Measurement', icon: Icons.water_drop_rounded,
          color: Color(0xFF22D3EE), unit: '%',
          instruction: 'Please remain still and keep the band fitted securely.',
          expectedSeconds: 30);
      case MeasurementType.bloodPressure:
        return const MeasurementTypeConfig(
          title: 'Blood Pressure Measurement', icon: Icons.speed_rounded,
          color: Color(0xFF34D399), unit: 'mmHg',
          instruction: 'Rest your arm and keep the band snug on your wrist.',
          expectedSeconds: 45);
      case MeasurementType.skinTemperature:
        return const MeasurementTypeConfig(
          title: 'Skin Temperature', icon: Icons.thermostat_rounded,
          color: Color(0xFFFB923C), unit: '°C',
          instruction: 'Please remain still and keep the band fitted securely.',
          expectedSeconds: 20);
      case MeasurementType.glucose:
        return const MeasurementTypeConfig(
          // FIX: was amber 0xFFF59E0B — glucose measurement pill is red.
          title: 'Blood Glucose', icon: Icons.bloodtype_rounded,
          color: Color(0xFFFF3B4E), unit: 'mg/dL',
          instruction: 'Keep the sensor in contact until the reading completes.',
          expectedSeconds: null);
      case MeasurementType.steps:
        return const MeasurementTypeConfig(
          title: 'Activity Sync', icon: Icons.directions_walk_rounded,
          color: Color(0xFFA3E635), unit: 'steps',
          instruction: 'Syncing activity data from your band…',
          expectedSeconds: null);
    }
  }
}

class CapsuleWaveMeasurementView extends StatefulWidget {
  final MeasurementType measurementType;
  final MeasurementState state;

  /// Genuine progress 0–1 from the SDK, or null → indeterminate.
  final double? progress;

  /// Genuine remaining seconds from the SDK, or null → hidden.
  final int? secondsRemaining;

  /// Validated result from the SDK (only shown in success state).
  final String? value;
  final String? unit;
  final String? failureReason;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback? onDone;

  const CapsuleWaveMeasurementView({
    super.key,
    required this.measurementType,
    required this.state,
    required this.onCancel,
    required this.onRetry,
    this.onDone,
    this.progress,
    this.secondsRemaining,
    this.value,
    this.unit,
    this.failureReason,
  });

  @override
  State<CapsuleWaveMeasurementView> createState() =>
      _CapsuleWaveMeasurementViewState();
}

class _CapsuleWaveMeasurementViewState
    extends State<CapsuleWaveMeasurementView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t; // master clock 0→1 looping
  MeasurementState? _announced;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _haptic(widget.state);
  }

  @override
  void didUpdateWidget(covariant CapsuleWaveMeasurementView old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _haptic(widget.state);
  }

  void _haptic(MeasurementState s) {
    if (_announced == s) return;
    _announced = s;
    switch (s) {
      case MeasurementState.measuring:
        HapticFeedback.lightImpact();          // soft start
        break;
      case MeasurementState.success:
        HapticFeedback.mediumImpact();         // success
        break;
      case MeasurementState.cancelled:
      case MeasurementState.deviceDisconnected:
        HapticFeedback.selectionClick();       // warning / interrupted
        break;
      case MeasurementState.failed:
        HapticFeedback.heavyImpact();          // error
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  MeasurementTypeConfig get _cfg =>
      MeasurementTypeConfig.of(widget.measurementType);

  String get _statusText {
    switch (widget.state) {
      case MeasurementState.preparing:  return 'Preparing device';
      case MeasurementState.measuring:  return 'Measuring';
      case MeasurementState.processing: return 'Processing your result';
      case MeasurementState.success:    return 'Complete';
      case MeasurementState.failed:     return 'Measurement failed';
      case MeasurementState.cancelled:  return 'Cancelled';
      case MeasurementState.deviceDisconnected:
        return 'The health band was disconnected. Reconnecting…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final isError = widget.state == MeasurementState.failed;
    final accent = isError ? const Color(0xFFFF5577) : cfg.color;

    return Semantics(
      liveRegion: true,
      label: '${cfg.title}. $_statusText.'
          '${widget.state == MeasurementState.success && widget.value != null ? ' ${widget.value} ${widget.unit ?? cfg.unit}' : ''}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Icon + title
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(color: accent.withOpacity(0.35))),
          child: Icon(cfg.icon, color: accent, size: 26)),
        const SizedBox(height: 12),
        Text(cfg.title,
          style: BMHText.labelLg.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),

        // Status line with animated ellipsis
        AnimatedBuilder(
          animation: _t,
          builder: (_, __) {
            final active = widget.state == MeasurementState.preparing ||
                widget.state == MeasurementState.measuring ||
                widget.state == MeasurementState.processing;
            var dots = '';
            if (active) {
              final n = _reduceMotion
                  ? ((_t.value * 2).floor() % 4)
                  : ((_t.value * 4).floor() % 4);
              dots = '.' * n;
            }
            return Text('$_statusText$dots',
              style: BMHText.bodySm.copyWith(color: BMHColors.inkDim));
          }),
        const SizedBox(height: 18),

        // ── THE CAPSULE ─────────────────────────────
        AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            // Subtle glow pulse every ~2s (skip on Reduce Motion)
            final pulse = _reduceMotion
                ? 0.0
                : (math.sin(_t.value * 2 * math.pi) + 1) / 2;
            return Container(
              width: 280, height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(42),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.10 + 0.10 * pulse),
                    blurRadius: 24 + 8 * pulse,
                    spreadRadius: 1),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 8)),
                ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(42),
                child: CustomPaint(
                  painter: _CapsulePainter(
                    time: _t.value,
                    color: accent,
                    state: widget.state,
                    progress: widget.progress,
                    reduceMotion: _reduceMotion,
                  ),
                  child: widget.state == MeasurementState.success
                      ? Center(
                          child: Icon(Icons.check_rounded,
                            color: Colors.white, size: 34))
                      : null,
                )));
          }),

        const SizedBox(height: 16),

        // Countdown — only when the SDK reports a genuine duration
        if (widget.secondsRemaining != null &&
            (widget.state == MeasurementState.measuring ||
             widget.state == MeasurementState.preparing)) ...[
          Text('${widget.secondsRemaining}',
            style: BMHText.labelLg.copyWith(
              fontSize: 30, fontWeight: FontWeight.w800, color: accent)),
          Text('seconds remaining',
            style: BMHText.monoSm.copyWith(color: BMHColors.inkMute)),
          const SizedBox(height: 10),
        ],

        // Result (success only — value comes validated from the SDK)
        if (widget.state == MeasurementState.success &&
            widget.value != null) ...[
          Text('${widget.value} ${widget.unit ?? cfg.unit}',
            style: BMHText.labelLg.copyWith(
              fontSize: 30, fontWeight: FontWeight.w800, color: accent)),
          Text(
            'Measured at ${TimeOfDay.now().format(context)}',
            style: BMHText.monoSm.copyWith(color: BMHColors.inkMute)),
          const SizedBox(height: 10),
        ],

        // Failure reason
        if (isError && widget.failureReason != null) ...[
          Text(widget.failureReason!,
            textAlign: TextAlign.center,
            style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
          const SizedBox(height: 10),
        ],

        // Instruction while active
        if (widget.state == MeasurementState.preparing ||
            widget.state == MeasurementState.measuring)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(cfg.instruction,
              textAlign: TextAlign.center,
              style: BMHText.bodySm.copyWith(color: BMHColors.inkMute))),

        const SizedBox(height: 20),

        // ── ACTIONS ─────────────────────────────────
        _actions(accent),
      ]),
    );
  }

  Widget _actions(Color accent) {
    switch (widget.state) {
      case MeasurementState.preparing:
      case MeasurementState.measuring:
      case MeasurementState.processing:
        return _btn('Cancel Measurement', outlined: true,
            color: BMHColors.inkDim, onTap: widget.onCancel);
      case MeasurementState.success:
        return _btn('Done', color: accent,
            onTap: widget.onDone ?? widget.onCancel);
      case MeasurementState.failed:
      case MeasurementState.cancelled:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _btn('Close', outlined: true,
              color: BMHColors.inkDim, onTap: widget.onCancel),
          const SizedBox(width: 12),
          _btn('Try Again', color: accent, onTap: widget.onRetry),
        ]);
      case MeasurementState.deviceDisconnected:
        return _btn('Cancel', outlined: true,
            color: BMHColors.inkDim, onTap: widget.onCancel);
    }
  }

  Widget _btn(String label,
      {required Color color, bool outlined = false,
       required VoidCallback onTap}) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 12))
        : ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: BMHColors.bg0,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 12));
    final child = Text(label,
        style: BMHText.labelLg.copyWith(
          fontWeight: FontWeight.w700,
          color: outlined ? color : BMHColors.bg0));
    return outlined
        ? OutlinedButton(style: style, onPressed: onTap, child: child)
        : ElevatedButton(style: style, onPressed: onTap, child: child);
  }
}

/// Paints the capsule interior: dark translucent background, thin
/// accent border, animated fluid with two wave layers, top highlight,
/// and drifting bubbles — all clipped by the parent ClipRRect.
class _CapsulePainter extends CustomPainter {
  final double time;            // 0–1 looping master clock
  final Color color;
  final MeasurementState state;
  final double? progress;       // genuine SDK progress or null
  final bool reduceMotion;

  _CapsulePainter({
    required this.time, required this.color, required this.state,
    required this.progress, required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
        rect, Radius.circular(size.height / 2));

    // Background — dark, slightly transparent
    canvas.drawRRect(rrect,
        Paint()..color = const Color(0xFF0A1220).withOpacity(0.85));

    // Fluid level (fraction of height filled)
    double level;
    switch (state) {
      case MeasurementState.success:    level = 1.0; break;
      case MeasurementState.failed:
      case MeasurementState.cancelled:  level = 0.12; break;
      case MeasurementState.preparing:  level = 0.35; break;
      case MeasurementState.processing: level = 0.65; break;
      default:
        // Fill from real progress only; otherwise a steady 55%
        level = progress != null
            ? 0.25 + 0.7 * progress!.clamp(0.0, 1.0)
            : 0.55;
    }

    final phase = time * 2 * math.pi;
    // Slow the wave in preparing/processing
    final speed = state == MeasurementState.measuring ? 1.0 : 0.5;
    // Organic amplitude variation
    final amp = reduceMotion
        ? 0.0
        : (5.0 + 2.0 * math.sin(phase * 0.5)) *
          (state == MeasurementState.success ? 0.0 : 1.0);

    final baseY = size.height * (1 - level);

    Path wave(double phaseShift, double ampScale) {
      final p = Path()..moveTo(0, size.height);
      p.lineTo(0, baseY);
      for (double x = 0; x <= size.width; x += 4) {
        final y = baseY +
            amp * ampScale *
                math.sin((x / size.width * 2 * math.pi * 1.6) +
                    phase * speed * 2 + phaseShift);
        p.lineTo(x, y);
      }
      p.lineTo(size.width, size.height);
      p.close();
      return p;
    }

    // Back wave layer (softer)
    canvas.drawPath(wave(math.pi / 1.4, 0.7),
        Paint()..color = color.withOpacity(0.22));
    // Front wave layer
    final front = wave(0, 1.0);
    canvas.drawPath(front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.55), color.withOpacity(0.30)],
          ).createShader(rect));

    // Soft highlight along the top of the liquid
    final hl = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    final hlPath = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final y = baseY +
          amp * math.sin((x / size.width * 2 * math.pi * 1.6) +
              phase * speed * 2);
      x == 0 ? hlPath.moveTo(x, y) : hlPath.lineTo(x, y);
    }
    canvas.drawPath(hlPath, hl);

    // Bubbles — deterministic pseudo-random, drift right + up,
    // fade in/out, clipped by the parent. Skipped on Reduce Motion.
    if (!reduceMotion &&
        state != MeasurementState.success &&
        state != MeasurementState.failed) {
      final rng = math.Random(7);
      for (int i = 0; i < 7; i++) {
        final seedX = rng.nextDouble();
        final seedY = rng.nextDouble();
        final r = 1.5 + rng.nextDouble() * 2.5;
        final spd = 0.4 + rng.nextDouble() * 0.8;
        final t = (time * spd + seedX) % 1.0;
        final bx = t * size.width;
        final by = size.height -
            (size.height * level - 8) * (0.25 + 0.7 * seedY) -
            t * 8; // slight upward drift
        if (by < baseY + 3) continue; // stay inside the fluid
        final fade = math.sin(t * math.pi); // fade in and out
        canvas.drawCircle(Offset(bx, by), r,
            Paint()..color = Colors.white.withOpacity(0.30 * fade));
      }
    }

    // Thin accent border with subtle internal glow
    canvas.drawRRect(rrect.deflate(0.8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withOpacity(0.65));
    canvas.drawRRect(rrect.deflate(2.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..color = color.withOpacity(0.15));
  }

  @override
  bool shouldRepaint(_CapsulePainter old) =>
      old.time != time || old.state != state ||
      old.progress != progress || old.color != color;
}

/// Convenience: show the measurement flow as a modal bottom sheet.
/// Drive [state] etc. from your BLE service — the sheet rebuilds
/// via the [ValueListenable]s you pass in.
Future<void> showCapsuleMeasurementModal({
  required BuildContext context,
  required MeasurementType type,
  required ValueNotifier<MeasurementState> state,
  ValueNotifier<int?>? secondsRemaining,
  ValueNotifier<double?>? progress,
  ValueNotifier<String?>? value,
  required VoidCallback onCancel,
  required VoidCallback onRetry,
}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: BMHColors.bg1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          state,
          if (secondsRemaining != null) secondsRemaining,
          if (progress != null) progress,
          if (value != null) value,
        ]),
        builder: (_, __) => CapsuleWaveMeasurementView(
          measurementType: type,
          state: state.value,
          secondsRemaining: secondsRemaining?.value,
          progress: progress?.value,
          value: value?.value,
          onCancel: () { onCancel(); Navigator.pop(ctx); },
          onDone:   () => Navigator.pop(ctx),
          onRetry:  onRetry,
        ))),
  );
}
