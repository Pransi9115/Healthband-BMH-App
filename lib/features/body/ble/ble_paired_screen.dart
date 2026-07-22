import 'package:flutter/material.dart';
import '../../../core/ble/ble_service.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../health/live_health_screen.dart';
import '../../../shared/widgets/bmh_screen.dart';
import '../../../shared/widgets/bmh_global_nav.dart';

class BlePairedScreen extends StatefulWidget {
  final BMHBleDevice device;
  final bool isScale;
  const BlePairedScreen({
    super.key, required this.device, this.isScale = false,
  });

  @override
  State<BlePairedScreen> createState() => _BlePairedScreenState();
}

class _BlePairedScreenState extends State<BlePairedScreen>
    with SingleTickerProviderStateMixin {
  final _ble = BleService.instance;
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();
    _checkAnim = CurvedAnimation(
      parent: _checkCtrl, curve: Curves.elasticOut,
    );
    _ble.addListener(_onBleChange);
  }

  void _onBleChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _ble.removeListener(_onBleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isScale ? BMHColors.sGut : BMHColors.sCardio;

    return BMHScreenBackground(
      glowColor: color,
      glowAlignment: Alignment.topLeft,
      bottomNavigationBar: const BMHGlobalNav(),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: BMHIconButton(
                  onTap: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                    color: BMHColors.ink, size: 16),
                ),
              ),

              const SizedBox(height: 40),

              // ── SUCCESS ICON ──────────────────────────
              ScaleTransition(
                scale: _checkAnim,
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.4), width: 2),
                    boxShadow: BMHShadows.glow(color),
                  ),
                  child: Icon(Icons.check_rounded,
                    color: color, size: 46),
                ),
              ),

              const SizedBox(height: 28),

              // ── HEADER ────────────────────────────────
              BMHEyebrow('Connected successfully', showDot: true),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: BMHText.displayMd.copyWith(fontSize: 30),
                  children: [
                    const TextSpan(text: 'Your '),
                    TextSpan(
                      text: widget.isScale ? 'BioScale' : 'Health Band',
                      style: TextStyle(
                        fontStyle: FontStyle.italic, color: color),
                    ),
                    const TextSpan(text: '\nis ready'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.device.name,
                style: BMHText.monoMd.copyWith(color: BMHColors.inkDim),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── LIVE DATA PREVIEW ─────────────────────
              if (!widget.isScale)
                _BandLivePreview(ble: _ble, color: color)
              else
                _ScaleLivePreview(color: color),

              const SizedBox(height: 24),

              // ── DEVICE STATUS CARD ────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BMHColors.bg3,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: color.withOpacity(0.28)),
                    ),
                    child: Icon(
                      widget.isScale
                          ? Icons.monitor_weight_outlined
                          : Icons.watch_outlined,
                      color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.device.name, style: BMHText.labelLg),
                      Text(
                        widget.device.id.length > 17
                            ? widget.device.id.substring(0, 17)
                            : widget.device.id,
                        style: BMHText.monoSm.copyWith(fontSize: 9)),
                    ],
                  )),
                  BMHPill('Connected', type: BMHPillType.success),
                ]),
              ),

              const SizedBox(height: 20),

              // ── DONE BUTTON — goes back to MainShell ──
              BMHButton(
                label: 'Go to Health Dashboard',
                color: color,
                onTap: () {
                  // Pop everything back to MainShell (first route)
                  Navigator.of(context).popUntil(
                    (route) => route.isFirst);
                },
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  int count = 0;
                  Navigator.of(context).popUntil((_) => count++ >= 2);
                },
                child: Text('Pair another device',
                  style: BMHText.labelLg.copyWith(color: color)),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BAND LIVE PREVIEW ─────────────────────────────────────

class _BandLivePreview extends StatelessWidget {
  final BleService ble;
  final Color color;
  const _BandLivePreview({required this.ble, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          BMHEyebrow('Live readings', showDot: true),
          if (ble.battery > 0)
            Row(children: [
              Icon(
                ble.battery > 50
                    ? Icons.battery_full_rounded
                    : Icons.battery_1_bar_rounded,
                color: ble.battery > 20
                    ? BMHColors.sGut : BMHColors.danger,
                size: 14),
              const SizedBox(width: 4),
              Text('${ble.battery}%',
                style: BMHText.monoSm.copyWith(fontSize: 10)),
            ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _LiveTile(
            label: 'Heart Rate',
            value: ble.heartRate > 0 ? '${ble.heartRate}' : '--',
            unit: 'bpm', color: BMHColors.sCardio,
            icon: Icons.favorite_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _LiveTile(
            label: 'SpO₂',
            value: ble.spo2 > 0 ? '${ble.spo2}' : '--',
            unit: '%', color: BMHColors.sOxygen,
            icon: Icons.water_drop_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _LiveTile(
            label: 'Temperature',
            value: ble.temperature > 0
                ? ble.temperature.toStringAsFixed(1) : '--',
            unit: '°C', color: BMHColors.sNervous,
            icon: Icons.thermostat_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _LiveTile(
            label: 'Steps',
            value: ble.steps > 0 ? '${ble.steps}' : '--',
            unit: 'today', color: BMHColors.sBody,
            icon: Icons.directions_walk_rounded)),
        ]),
        // Only prompt once the hardware confirms the band is off the
        // wrist. While the wear probe is still in flight we say
        // "checking", so a correctly worn band never gets told off.
        if (ble.isWearChecking && ble.heartRate == 0) ...[
          const SizedBox(height: 12),
          Text('Checking band contact…',
            style: BMHText.monoSm.copyWith(fontSize: 9),
            textAlign: TextAlign.center),
        ] else if (ble.isConfirmedOffWrist && ble.heartRate == 0) ...[
          const SizedBox(height: 12),
          Text('Wear the band to see live readings',
            style: BMHText.monoSm.copyWith(fontSize: 9),
            textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

class _LiveTile extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _LiveTile({
    required this.label, required this.value,
    required this.unit, required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: value,
            style: BMHText.displaySm.copyWith(
              fontSize: 22, color: color, height: 1)),
          TextSpan(text: ' $unit',
            style: BMHText.monoSm.copyWith(fontSize: 9)),
        ])),
        const SizedBox(height: 2),
        Text(label, style: BMHText.monoSm.copyWith(fontSize: 9)),
      ]),
    );
  }
}

// ── SCALE LIVE PREVIEW ────────────────────────────────────

class _ScaleLivePreview extends StatelessWidget {
  final Color color;
  const _ScaleLivePreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(children: [
        BMHEyebrow('Step on scale to measure', showDot: true),
        const SizedBox(height: 16),
        Icon(Icons.monitor_weight_outlined, color: color, size: 48),
        const SizedBox(height: 12),
        Text(
          'Stand on your BioScale to\nget your first reading',
          style: BMHText.italic, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          BMHPulsingDot(color: color, size: 6),
          const SizedBox(width: 8),
          Text('Waiting for reading...',
            style: BMHText.monoSm.copyWith(color: color)),
        ]),
      ]),
    );
  }
}
