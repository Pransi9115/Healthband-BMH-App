import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/ble/ble_service.dart';

// ─────────────────────────────────────────────────────────
//  LIVE HEALTH SCREEN
//  Shows real-time vitals from the connected band
// ─────────────────────────────────────────────────────────
class LiveHealthScreen extends StatefulWidget {
  const LiveHealthScreen({super.key});

  @override
  State<LiveHealthScreen> createState() => _LiveHealthScreenState();
}

class _LiveHealthScreenState extends State<LiveHealthScreen> {
  final _ble = BleService.instance;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBle);
  }

  void _onBle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ble.removeListener(_onBle);
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
        title: Text('Live Vitals',
          style: BMHText.heading2.copyWith(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(BMHSpacing.screenH),
        children: [
          _LiveTile(
            label: 'Heart Rate',
            value: _ble.heartRate > 0 ? '${_ble.heartRate}' : '--',
            unit: 'bpm',
            icon: Icons.favorite_border_rounded,
            color: BMHColors.sCardio,
            isLive: _ble.heartRate > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'SpO₂',
            value: _ble.spo2 > 0 ? '${_ble.spo2}' : '--',
            unit: '%',
            icon: Icons.water_drop_outlined,
            color: BMHColors.sOxygen,
            isLive: _ble.spo2 > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'HRV',
            value: _ble.hrv > 0 ? '${_ble.hrv}' : '--',
            unit: 'ms',
            icon: Icons.graphic_eq_rounded,
            color: BMHColors.sGut,
            isLive: _ble.hrv > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'Temperature',
            value: _ble.temperature > 0
                ? _ble.temperature.toStringAsFixed(1) : '--',
            unit: '°C',
            icon: Icons.thermostat_outlined,
            color: BMHColors.sNervous,
            isLive: _ble.temperature > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'Blood Pressure',
            value: _ble.bloodPressure,
            unit: 'mmHg',
            icon: Icons.bloodtype_outlined,
            color: BMHColors.sCardio,
            isLive: _ble.bpSystolic > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'Stress Level',
            value: _ble.stressLevel > 0 ? '${_ble.stressLevel}' : '--',
            unit: '/100',
            icon: Icons.psychology_outlined,
            color: BMHColors.sMetabolic,
            isLive: _ble.stressLevel > 0),
          const SizedBox(height: 10),
          _LiveTile(
            label: 'Steps Today',
            value: '${_ble.steps}',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            color: BMHColors.sBody,
            isLive: _ble.isBandConnected),
        ],
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final bool isLive;

  const _LiveTile({
    required this.label, required this.value, required this.unit,
    required this.icon, required this.color, required this.isLive});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: BMHText.bodyMd)),
      if (isLive)
        Container(
          width: 5, height: 5,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.5), blurRadius: 4)])),
      Text.rich(TextSpan(children: [
        TextSpan(text: value,
          style: BMHText.displaySm.copyWith(
            fontFamily: 'JetBrains Mono',
            fontSize: 17,
            color: value == '--' ? BMHColors.inkMute : color,
            height: 1)),
        TextSpan(text: ' $unit',
          style: BMHText.monoSm.copyWith(
            color: BMHColors.inkMute, fontSize: 9)),
      ])),
    ]));
}
