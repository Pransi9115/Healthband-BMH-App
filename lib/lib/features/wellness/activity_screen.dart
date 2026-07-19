import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/ble/ble_service.dart';
import '../../core/health/vital_history_service.dart';

/// ─────────────────────────────────────────────────────────
///  ACTIVITY — steps, distance, calories, exercise minutes
///  Live from the connected band + weekly steps history.
/// ─────────────────────────────────────────────────────────
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _ble = BleService.instance;
  final _hist = VitalHistoryService.instance;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onUpdate);
    _hist.addListener(_onUpdate);
  }

  void _onUpdate() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _ble.removeListener(_onUpdate);
    _hist.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _ble.steps;
    final goal  = _ble.stepGoal > 0 ? _ble.stepGoal : 10000;
    final prog  = (steps / goal).clamp(0.0, 1.0);
    final weekSpots = _hist.getSpots('steps', 1);

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 2),
      body: Stack(children: [
        Positioned(top: -180, left: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                BMHColors.sOxygen.withOpacity(0.08),
                Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
          // ── HEADER with back button ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BMHEyebrow('Wellness · activity',
                    showDot: _ble.isBandConnected),
                  Text('Activity', style: BMHText.heading1),
                ])),
            ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── GOAL RING CARD ──────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(children: [
                    SizedBox(width: 96, height: 96, child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(width: 96, height: 96,
                          child: CircularProgressIndicator(
                            value: prog, strokeWidth: 7,
                            backgroundColor: BMHColors.bg4,
                            valueColor: AlwaysStoppedAnimation(
                              prog >= 1.0
                                  ? BMHColors.sGut : BMHColors.sOxygen))),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${(prog * 100).round()}%',
                            style: BMHText.heading2.copyWith(
                              color: BMHColors.sOxygen)),
                          Text('of goal',
                            style: BMHText.monoSm.copyWith(fontSize: 8)),
                        ]),
                      ])),
                    const SizedBox(width: 20),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$steps',
                          style: BMHText.displaySm.copyWith(
                            fontSize: 34, color: BMHColors.ink)),
                        Text('steps today',
                          style: BMHText.monoSm.copyWith(
                            color: BMHColors.inkMute)),
                        const SizedBox(height: 6),
                        Text('Goal: $goal',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 9, color: BMHColors.sOxygen)),
                      ])),
                  ])),
                const SizedBox(height: 14),

                // ── METRIC ROW ──────────────────────────
                Row(children: [
                  _metric('Distance',
                    _ble.distance > 0
                        ? _ble.distance.toStringAsFixed(2) : '--',
                    'km', Icons.route_rounded, BMHColors.sBody),
                  const SizedBox(width: 10),
                  _metric('Calories',
                    _ble.calories > 0
                        ? _ble.calories.round().toString() : '--',
                    'kcal', Icons.local_fire_department_rounded,
                    BMHColors.sMetabolic),
                  const SizedBox(width: 10),
                  _metric('Exercise',
                    _ble.exerciseMin > 0 ? '${_ble.exerciseMin}' : '--',
                    'min', Icons.timer_rounded, BMHColors.sGut),
                ]),
                const SizedBox(height: 24),

                // ── WEEKLY STEPS CHART ──────────────────
                BMHSectionTitle('This Week'),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: BMHColors.line)),
                  child: weekSpots.isEmpty
                    ? Center(child: Text('No step history yet',
                        style: BMHText.monoSm.copyWith(
                          color: BMHColors.inkMute)))
                    : BarChart(BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: false),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 34,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000
                                  ? '${(v / 1000).toStringAsFixed(0)}k'
                                  : v.toInt().toString(),
                              style: BMHText.monoSm.copyWith(
                                fontSize: 7,
                                color: const Color(0xFF2DD4BF))))),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 18,
                            getTitlesWidget: (v, _) {
                              const d = ['MON','TUE','WED','THU',
                                         'FRI','SAT','SUN'];
                              final i = v.round();
                              if (i < 0 || i > 6) return const SizedBox();
                              return Text(d[i],
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 7,
                                  color: const Color(0xFF2DD4BF)));
                            }))),
                        barGroups: List.generate(7, (i) {
                          final spot = weekSpots
                              .where((s) => s.x.toInt() == i)
                              .toList();
                          final y = spot.isEmpty ? 0.0 : spot.first.y;
                          return BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: y, width: 14,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                              color: BMHColors.sOxygen
                                  .withOpacity(y > 0 ? 0.9 : 0.15)),
                          ]);
                        }))),
                ),
                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  Widget _metric(String label, String value, String unit,
      IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 8),
        Text(value, style: BMHText.heading2.copyWith(fontSize: 18)),
        Text(unit, style: BMHText.monoSm.copyWith(
          fontSize: 8, color: BMHColors.inkMute)),
        const SizedBox(height: 2),
        Text(label, style: BMHText.monoSm.copyWith(
          fontSize: 8, color: color)),
      ])));
  }
}
