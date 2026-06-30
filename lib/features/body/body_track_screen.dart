import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_screen.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/ble/ble_service.dart';
import '../body/ble/ble_intro_screen.dart';

// ─────────────────────────────────────────────
//  BODY TRACK SCREEN
//  BioScale weight + body composition
// ─────────────────────────────────────────────

class BodyTrackScreen extends StatefulWidget {
  const BodyTrackScreen({super.key});

  @override
  State<BodyTrackScreen> createState() => _BodyTrackScreenState();
}

class _BodyTrackScreenState extends State<BodyTrackScreen>
    with SingleTickerProviderStateMixin {
  final _ble = BleService.instance;
  int _rangeIndex = 0;
  late final AnimationController _scaleCtrl;

  // Sample weight history data
  final _weightHistory = [
    [0.0, 76.2], [1.0, 75.8], [2.0, 75.5], [3.0, 75.9],
    [4.0, 75.3], [5.0, 74.8], [6.0, 74.2],
  ];

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..forward();
    _ble.addListener(_onBleChange);
  }

  void _onBleChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _ble.removeListener(_onBleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use real scale data if available, otherwise demo
    final weight = 74.2;
    final fatPct = 18.4;
    final musclePct = 42.1;
    final waterPct = 56.2;
    final bmi = 22.8;
    final visceralFat = 8;
    final boneMass = 3.2;

    return BMHScreenBackground(
      glowColor: BMHColors.sGut,
      glowAlignment: Alignment.topLeft,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── TOP BAR ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH, vertical: 8),
              child: Row(children: [
                BMHIconButton(
                  onTap: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                    color: BMHColors.ink, size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BMHEyebrow('Body composition', showDot: true),
                    Text('Body Track', style: BMHText.heading1),
                  ],
                )),
                // Scale status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _ble.isScaleConnected
                        ? BMHColors.sGut.withOpacity(0.12)
                        : BMHColors.bg4,
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(
                      color: _ble.isScaleConnected
                          ? BMHColors.sGut.withOpacity(0.3)
                          : BMHColors.line),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    BMHPulsingDot(
                      color: _ble.isScaleConnected
                          ? BMHColors.sGut
                          : BMHColors.inkMute,
                      size: 5,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _ble.isScaleConnected ? 'Scale Live' : 'No Scale',
                      style: BMHText.monoSm.copyWith(
                        color: _ble.isScaleConnected
                            ? BMHColors.sGut
                            : BMHColors.inkMute,
                        fontSize: 9,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: BMHSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── CONNECT SCALE BANNER ──────────────
                    if (!_ble.isScaleConnected)
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                            const BleIntroScreen(isScale: true))),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: BMHColors.sGut.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(BMHRadius.md),
                            border: Border.all(
                              color: BMHColors.sGut.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            Icon(Icons.monitor_weight_outlined,
                              color: BMHColors.sGut, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Connect BioScale for live readings — showing demo data',
                                style: BMHText.bodySm.copyWith(
                                  color: BMHColors.inkDim)),
                            ),
                            Icon(Icons.chevron_right_rounded,
                              color: BMHColors.sGut, size: 16),
                          ]),
                        ),
                      ),

                    // ── WEIGHT HERO CARD ──────────────────
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.xl),
                        border: Border.all(
                          color: BMHColors.sGut.withOpacity(0.25)),
                        boxShadow: BMHShadows.card,
                      ),
                      child: Stack(children: [
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          child: const BMHScanLineFigure(
                            width: 80, height: 120, opacity: 0.12),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              BMHEyebrow('Current weight'),
                              const Spacer(),
                              BMHPill('↓ 2.0 kg this week',
                                type: BMHPillType.success),
                            ]),
                            const SizedBox(height: 16),
                            // Weight number
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  weight.toStringAsFixed(1),
                                  style: BMHText.displayXl.copyWith(
                                    fontSize: 68, height: 1,
                                    color: BMHColors.ink,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 12, left: 6),
                                  child: Text('kg',
                                    style: BMHText.monoLg.copyWith(
                                      color: BMHColors.inkMute,
                                      fontSize: 18)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // BMI
                            Row(children: [
                              Text('BMI: ',
                                style: BMHText.monoSm),
                              Text(bmi.toStringAsFixed(1),
                                style: BMHText.monoMd.copyWith(
                                  color: BMHColors.sGut,
                                  fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              BMHPill('Healthy',
                                type: BMHPillType.success),
                            ]),
                          ],
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ── BMI SCALE ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BMHColors.surface,
                        borderRadius: BorderRadius.circular(BMHRadius.lg),
                        border: Border.all(color: BMHColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BMI Scale'.toUpperCase(),
                            style: BMHText.monoSm),
                          const SizedBox(height: 12),
                          // BMI bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 12,
                              child: Row(children: [
                                Expanded(flex: 2,
                                  child: Container(color: BMHColors.sOxygen)),
                                Expanded(flex: 3,
                                  child: Container(color: BMHColors.sGut)),
                                Expanded(flex: 2,
                                  child: Container(color: BMHColors.sMetabolic)),
                                Expanded(flex: 3,
                                  child: Container(color: BMHColors.danger)),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Under\n<18.5',
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 8, color: BMHColors.sOxygen),
                                textAlign: TextAlign.center),
                              Text('Normal\n18.5-25',
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 8, color: BMHColors.sGut),
                                textAlign: TextAlign.center),
                              Text('Over\n25-30',
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 8, color: BMHColors.sMetabolic),
                                textAlign: TextAlign.center),
                              Text('Obese\n>30',
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 8, color: BMHColors.danger),
                                textAlign: TextAlign.center),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Your BMI: $bmi — Healthy range ✓',
                            style: BMHText.monoMd.copyWith(
                              color: BMHColors.sGut)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── WEIGHT CHART ──────────────────────
                    BMHSectionTitle(
                      'Weight history',
                      linkLabel: 'All data',
                    ),
                    const SizedBox(height: 16),

                    // Range toggle
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                        border: Border.all(color: BMHColors.line),
                      ),
                      child: Row(
                        children: ['Week', 'Month', '3 Months']
                            .asMap().entries.map((e) {
                          final active = e.key == _rangeIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _rangeIndex = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: active
                                      ? BMHColors.sGut
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(e.value,
                                    style: BMHText.labelMd.copyWith(
                                      color: active
                                          ? BMHColors.bg0
                                          : BMHColors.inkMute,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Weight line chart
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.lg),
                        border: Border.all(color: BMHColors.line),
                      ),
                      child: LineChart(LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: BMHColors.line,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(1),
                                style: BMHText.monoSm.copyWith(fontSize: 8)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final days = ['Mon', 'Tue', 'Wed', 'Thu',
                                  'Fri', 'Sat', 'Sun'];
                                final i = v.toInt();
                                if (i >= 0 && i < days.length) {
                                  return Text(days[i],
                                    style: BMHText.monoSm.copyWith(
                                      fontSize: 8));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 73, maxY: 77,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _weightHistory
                                .map((p) => FlSpot(p[0], p[1]))
                                .toList(),
                            isCurved: true,
                            color: BMHColors.sGut,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                radius: 3,
                                color: BMHColors.sGut,
                                strokeWidth: 1.5,
                                strokeColor: BMHColors.bg0,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  BMHColors.sGut.withOpacity(0.2),
                                  BMHColors.sGut.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )),
                    ),

                    const SizedBox(height: 26),

                    // ── BODY COMPOSITION ──────────────────
                    BMHSectionTitle('Body composition'),
                    const SizedBox(height: 16),

                    // Composition grid
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.9,
                      children: [
                        _CompoTile(
                          label: 'Body Fat',
                          value: '${fatPct}%',
                          subtext: 'Normal',
                          color: BMHColors.sNervous,
                          icon: Icons.water_outlined,
                          isOk: fatPct < 25,
                        ),
                        _CompoTile(
                          label: 'Muscle',
                          value: '${musclePct}%',
                          subtext: 'Good',
                          color: BMHColors.sGut,
                          icon: Icons.fitness_center_rounded,
                          isOk: true,
                        ),
                        _CompoTile(
                          label: 'Water',
                          value: '${waterPct}%',
                          subtext: 'Normal',
                          color: BMHColors.sOxygen,
                          icon: Icons.water_drop_rounded,
                          isOk: true,
                        ),
                        _CompoTile(
                          label: 'Bone Mass',
                          value: '${boneMass}kg',
                          subtext: 'Normal',
                          color: BMHColors.sDna,
                          icon: Icons.accessibility_new_rounded,
                          isOk: true,
                        ),
                        _CompoTile(
                          label: 'Visceral',
                          value: '$visceralFat',
                          subtext: 'Healthy',
                          color: BMHColors.sMetabolic,
                          icon: Icons.favorite_outline_rounded,
                          isOk: visceralFat < 10,
                        ),
                        _CompoTile(
                          label: 'BMI',
                          value: '$bmi',
                          subtext: 'Healthy',
                          color: BMHColors.cyan,
                          icon: Icons.monitor_weight_outlined,
                          isOk: bmi < 25,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── STEP ON SCALE CTA ─────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            BMHColors.sGut.withOpacity(0.12),
                            BMHColors.sGut.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(BMHRadius.lg),
                        border: Border.all(
                          color: BMHColors.sGut.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BMHEyebrow('New measurement'),
                            const SizedBox(height: 8),
                            Text.rich(TextSpan(
                              style: BMHText.heading2.copyWith(
                                fontFamily: 'Fraunces'),
                              children: const [
                                TextSpan(text: 'Step on your '),
                                TextSpan(text: 'BioScale',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: BMHColors.sGut)),
                              ],
                            )),
                            const SizedBox(height: 4),
                            Text('Auto-detects when you step on',
                              style: BMHText.italic.copyWith(fontSize: 12)),
                          ],
                        )),
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: BMHColors.sGut,
                            shape: BoxShape.circle,
                            boxShadow: BMHShadows.glow(BMHColors.sGut),
                          ),
                          child: const Icon(
                            Icons.monitor_weight_outlined,
                            color: BMHColors.bg0, size: 22),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── COMPOSITION TILE ──────────────────────────────────────

class _CompoTile extends StatelessWidget {
  final String label, value, subtext;
  final Color color;
  final IconData icon;
  final bool isOk;

  const _CompoTile({
    required this.label, required this.value,
    required this.subtext, required this.color,
    required this.icon, required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: BMHText.displaySm.copyWith(
                fontSize: 18, color: color, height: 1)),
              const SizedBox(height: 2),
              Text(label, style: BMHText.monoSm.copyWith(fontSize: 8)),
              Text(subtext, style: BMHText.monoSm.copyWith(
                fontSize: 8,
                color: isOk ? BMHColors.sGut : BMHColors.danger)),
            ],
          ),
        ],
      ),
    );
  }
}
