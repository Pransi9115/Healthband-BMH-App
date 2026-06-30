import 'package:flutter/material.dart';
import '../../../core/ble/ble_service.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import 'ble_paired_screen.dart';

class BleConnectingScreen extends StatefulWidget {
  final BMHBleDevice device;
  final bool isScale;
  const BleConnectingScreen({
    super.key, required this.device, this.isScale = false,
  });

  @override
  State<BleConnectingScreen> createState() => _BleConnectingScreenState();
}

class _BleConnectingScreenState extends State<BleConnectingScreen>
    with TickerProviderStateMixin {
  final _ble = BleService.instance;
  late final AnimationController _ringCtrl;
  late final AnimationController _pulseCtrl;
  String _status = 'Connecting...';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _connect();
  }

  Future<void> _connect() async {
    setState(() => _status = 'Connecting to ${widget.device.name}...');
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _status = 'Establishing secure link...');
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _status = 'Syncing health data...');

    final ok = await _ble.connectDevice(widget.device);

    if (!mounted) return;
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 400));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlePairedScreen(
            device: widget.device,
            isScale: widget.isScale,
          ),
        ),
      );
    } else {
      setState(() {
        _failed = true;
        _status = _ble.error ?? 'Connection failed. Please try again.';
      });
      _ringCtrl.stop();
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isScale ? BMHColors.sGut : BMHColors.sCardio;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        // Ambient glow
        Center(
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withOpacity(_failed ? 0.04 : 0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
            child: Column(children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: BMHIconButton(
                  onTap: _failed ? () => Navigator.pop(context) : null,
                  icon: Icon(
                    _failed
                        ? Icons.close_rounded
                        : Icons.bluetooth_rounded,
                    color: _failed ? BMHColors.ink : color,
                    size: 16,
                  ),
                ),
              ),

              const Spacer(),

              // ── CONNECTING ANIMATION ─────────────────
              SizedBox(
                width: 200, height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  // Spinning ring
                  if (!_failed)
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, __) => Transform.rotate(
                        angle: _ringCtrl.value * 2 * 3.14159,
                        child: Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.transparent, width: 2),
                            gradient: SweepGradient(
                              colors: [
                                color.withOpacity(0.0),
                                color.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Failed X ring
                  if (_failed)
                    Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BMHColors.danger.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    ),

                  // Inner pulse circle
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _failed
                            ? BMHColors.danger.withOpacity(0.08)
                            : color.withOpacity(0.08 + 0.04 * _pulseCtrl.value),
                        border: Border.all(
                          color: _failed
                              ? BMHColors.danger.withOpacity(0.3)
                              : color.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // Device icon centre
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _failed
                          ? BMHColors.danger.withOpacity(0.12)
                          : color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _failed
                          ? Icons.bluetooth_disabled_rounded
                          : widget.isScale
                              ? Icons.monitor_weight_outlined
                              : Icons.watch_outlined,
                      color: _failed ? BMHColors.danger : color,
                      size: 32,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 40),

              // ── STATUS TEXT ──────────────────────────
              Text(
                widget.device.name,
                style: BMHText.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: _failed
                    ? BMHText.bodyMd.copyWith(color: BMHColors.danger)
                    : BMHText.italic,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Loading dots
              if (!_failed) _LoadingDots(color: color),

              const Spacer(),

              // ── RETRY BUTTON (on fail) ───────────────
              if (_failed) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: BMHColors.bg0,
                  ),
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _status = 'Connecting...';
                    });
                    _ringCtrl.repeat();
                    _pulseCtrl.repeat(reverse: true);
                    _connect();
                  },
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Scan'),
                ),
              ],

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── LOADING DOTS ──────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final opacity = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
          return Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(opacity.clamp(0.2, 1.0)),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
