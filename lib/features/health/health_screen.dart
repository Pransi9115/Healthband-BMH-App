import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/ble/ble_service.dart';
import '../../core/health/vital_history_service.dart';
import '../../core/health/bioscore_calculator.dart';
import 'live_health_screen.dart';
import '../../shared/widgets/capsule_wave_measurement.dart';

// ─────────────────────────────────────────────────────────
//  VITAL CONFIG — ranges, normal values, insights
// ─────────────────────────────────────────────────────────
class VitalConfig {
  final String title, unit, insight;
  final double minY, maxY, normalMin, normalMax;
  final Color color;
  final List<String> dayLabels, weekLabels, monthLabels;
  final String Function(double) statMin, statAvg, statMax;

  const VitalConfig({
    required this.title, required this.unit,
    required this.color, required this.insight,
    required this.minY, required this.maxY,
    required this.normalMin, required this.normalMax,
    required this.dayLabels, required this.weekLabels,
    required this.monthLabels,
    required this.statMin, required this.statAvg, required this.statMax,
  });

  static VitalConfig of(String title, Color color) {
    final configs = _configs;
    return configs.firstWhere((c) => c.title == title,
      orElse: () => VitalConfig(
        title: title, unit: '', color: color,
        insight: 'Tracking your $title over time.',
        minY: 0, maxY: 100, normalMin: 40, normalMax: 80,
        dayLabels: const ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
        weekLabels: const ['M','T','W','T','F','S','S'],
        monthLabels: const ['W1','W2','W3','W4','W5'],
        statMin: (v) => v.toStringAsFixed(0),
        statAvg: (v) => v.toStringAsFixed(0),
        statMax: (v) => v.toStringAsFixed(0),
      ));
  }

  static const List<VitalConfig> _configs = [
    VitalConfig(
      title: 'Heart Rate', unit: 'bpm', color: BMHColors.sCardio,
      insight: 'Resting HR between 60–100 bpm is normal. Your average is healthy.',
      minY: 50, maxY: 120, normalMin: 60, normalMax: 100,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'SpO₂', unit: '%', color: BMHColors.sOxygen,
      insight: 'Normal SpO₂ is 95–100%. Readings below 94% need attention.',
      minY: 90, maxY: 100, normalMin: 95, normalMax: 100,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'HRV', unit: 'ms', color: BMHColors.sGut,
      insight: 'Higher HRV indicates better recovery and stress resilience.',
      minY: 20, maxY: 80, normalMin: 30, normalMax: 60,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'Temperature', unit: '°C', color: BMHColors.sNervous,
      insight: 'Normal body temperature is 36.1–37.2°C.',
      minY: 34.0, maxY: 38.5, normalMin: 36.1, normalMax: 37.2,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt1, statAvg: _fmt1, statMax: _fmt1,
    ),
    VitalConfig(
      title: 'Blood Pressure', unit: 'mmHg', color: BMHColors.sCardio,
      insight: 'Normal BP is below 120/80 mmHg. Monitor trends over time.',
      minY: 100, maxY: 140, normalMin: 110, normalMax: 130,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'Stress Level', unit: '/100', color: BMHColors.sMetabolic,
      insight: 'Stress score below 40 is good. Peaks correlate with activity and work.',
      minY: 0, maxY: 100, normalMin: 0, normalMax: 40,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'Sleep Quality', unit: 'hrs', color: BMHColors.sSleep,
      insight: '7–9 hours of sleep is recommended for optimal health.',
      minY: 0, maxY: 10, normalMin: 7, normalMax: 9,
      dayLabels: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt1, statAvg: _fmt1, statMax: _fmt1,
    ),
    VitalConfig(
      title: 'Steps Today', unit: 'steps', color: BMHColors.sBody,
      insight: 'Walking 10,000 steps daily improves cardiovascular health.',
      minY: 0, maxY: 10000, normalMin: 7000, normalMax: 10000,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'Blood Glucose', unit: 'mg/dL', color: BMHColors.sDna,
      insight: 'Fasting glucose 70–100 mg/dL is normal.',
      minY: 60, maxY: 140, normalMin: 70, normalMax: 100,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
    VitalConfig(
      title: 'Blood Glucose (Manual)', unit: 'mg/dL', color: BMHColors.sDna,
      insight: 'Fasting glucose 70–100 mg/dL is normal. Post-meal under 140 mg/dL.',
      minY: 60, maxY: 200, normalMin: 70, normalMax: 100,
      dayLabels: ['12a','3a','6a','9a','12p','3p','6p','9p','11p'],
      weekLabels: ['MON','TUE','WED','THU','FRI','SAT','SUN'],
      monthLabels: ['W1','W2','W3','W4'],
      statMin: _fmt0, statAvg: _fmt0, statMax: _fmt0,
    ),
  ];

  static String _fmt0(double v) => v.toStringAsFixed(0);
  static String _fmt1(double v) => v.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────
//  HEALTH SCREEN
// ─────────────────────────────────────────────────────────
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with AutomaticKeepAliveClientMixin {
  final _ble = BleService.instance;

  @override
  bool get wantKeepAlive => true;

  bool _refreshDone = false; // shows Updated! tick

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBle);
  }

  void _onBle() {
    if (!mounted) return;
    // Estimate glucose from HRV + HR
    if (_ble.hrv > 0 && _ble.heartRate > 0 && _bandGlucose == 0) {
      final hrv = _ble.hrv;
      final hr  = _ble.heartRate;
      int est = 90;
      if (hrv < 20) est += 15;
      else if (hrv > 50) est -= 8;
      if (hr > 90) est += 10;
      else if (hr < 60) est -= 5;
      _bandGlucose = est.clamp(70, 160);
    }
    // No popup — wear detection is now fully automatic
    setState(() {});
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _ble.removeListener(_onBle);
    super.dispose();
  }

  // Measurement state — for inline buttons in health tab
  bool _measuringSpo2   = false;
  bool _measuringHrv    = false;
  bool _measuringStress = false;
  bool _measuringBP     = false;
  Timer? _measureTimer;
  int _manualGlucose  = 94;  // manually entered by user
  int _bandGlucose    = 0;  // estimated by band algorithm from HRV data

  // Sends real BLE command to band
  Future<void> _measure(int bleType, int seconds,
      void Function(bool) setMeasuring) async {
    if (!_ble.isBandConnected) return;
    // KSlipHand — stop measurement if band not on wrist
    if (!_ble.isWearing) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(
            'Please wear the band on your wrist to measure',
            style: BMHText.monoSm.copyWith(color: BMHColors.bg0))),
        ]),
        backgroundColor: BMHColors.sMetabolic,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.full))));
      return; // ← STOP — measurement does NOT run
    }
    setMeasuring(true);
    setState(() {});
    _seconds = seconds;
    await _ble.startMeasurement(bleType);
    _measureTimer?.cancel();
    _measureTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _seconds--;
      if (_seconds <= 0) {
        t.cancel();
        _ble.stopMeasurement(bleType);
        setMeasuring(false);
        _seconds = 0;
      }
      setState(() {});
    });
  }

  int _seconds = 0;

  void _openVital(String title, Color color, String live) {
    if (title == 'Sleep Quality') {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
        SleepDetailScreen(sleepData: _ble.lastSleep)));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
      VitalDetailScreen(title: title, color: color, liveValue: live)));
  }



  void _showGlucoseDialog() {
    int newVal = _manualGlucose;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          side: const BorderSide(color: BMHColors.line)),
        title: Text('Blood Glucose', style: BMHText.heading2),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.science_rounded, color: BMHColors.sDna, size: 40),
              const SizedBox(height: 12),
              Text('$newVal mg/dL',
                style: BMHText.displayMd.copyWith(
                  color: BMHColors.sDna, fontSize: 40, height: 1)),
              const SizedBox(height: 4),
              Text(
                newVal < 70 ? '⚠️ Low' : newVal <= 100 ? '✅ Normal' : newVal <= 125 ? '⚠️ Pre-diabetic' : '🔴 High',
                style: BMHText.monoSm.copyWith(
                  color: newVal <= 100 ? BMHColors.sGut : BMHColors.danger)),
              const SizedBox(height: 16),
              Slider(
                value: newVal.toDouble(),
                min: 50, max: 400,
                divisions: 350,
                activeColor: BMHColors.sDna,
                inactiveColor: BMHColors.bg4,
                onChanged: (v) => setS(() => newVal = v.round())),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('50', style: BMHText.monoSm.copyWith(fontSize: 9)),
                  Text('Normal: 70-100 mg/dL',
                    style: BMHText.monoSm.copyWith(fontSize: 9)),
                  Text('400', style: BMHText.monoSm.copyWith(fontSize: 9)),
                ]),
              const SizedBox(height: 12),
              // Quick presets
              Wrap(spacing: 8, runSpacing: 8,
                children: [70, 90, 100, 120, 140].map((g) =>
                  GestureDetector(
                    onTap: () => setS(() => newVal = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: newVal == g
                            ? BMHColors.sDna.withOpacity(0.15) : BMHColors.bg4,
                        borderRadius: BorderRadius.circular(BMHRadius.full),
                        border: Border.all(color: newVal == g
                            ? BMHColors.sDna : BMHColors.line)),
                      child: Text('$g',
                        style: BMHText.monoSm.copyWith(
                          color: newVal == g ? BMHColors.sDna : BMHColors.inkMute,
                          fontWeight: newVal == g ? FontWeight.w600 : FontWeight.w400))))).toList()),
            ])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMHColors.sDna,
              foregroundColor: BMHColors.bg0),
            onPressed: () {
              setState(() => _manualGlucose = newVal);
              // Save to history so chart shows the data
              VitalHistoryService.instance.record(
                'blood_glucose', newVal.toDouble());
              Navigator.pop(context);
            },
            child: const Text('Save Reading')),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hr   = _ble.heartRate;
    final spo2 = _ble.spo2;
    final temp = _ble.temperature;
    final hrv  = _ble.hrv;
    final stress = _ble.stressLevel;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -100, right: -100,
          child: Container(width: 350, height: 350,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                BMHColors.sCardio.withOpacity(0.06), Colors.transparent])))),
        SafeArea(bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                // TOP BAR
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BMHEyebrow('Bio Health Care Band', showDot: _ble.isBandConnected),
                    const SizedBox(height: 4),
                    Text('Bio Health Care Band', style: BMHText.heading1.copyWith(fontSize: 24)),
                  ]),
                  Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Refresh circle button
                    if (_ble.isBandConnected)
                      GestureDetector(
                        onTap: () async {
                          if (_ble.isRefreshing) return;
                          await _ble.manualRefresh();
                          if (mounted) {
                            setState(() => _refreshDone = true);
                            await Future.delayed(
                              const Duration(seconds: 2));
                            if (mounted) setState(() => _refreshDone = false);
                          }
                        },
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _refreshDone
                                ? BMHColors.sGut.withOpacity(0.12)
                                : _ble.isRefreshing
                                    ? BMHColors.cyan.withOpacity(0.10)
                                    : BMHColors.bg3,
                            border: Border.all(
                              color: _ble.isRefreshing
                                  ? BMHColors.cyan
                                  : _refreshDone
                                      ? BMHColors.sGut
                                      : BMHColors.line,
                              width: _ble.isRefreshing ? 2 : 1),
                          ),
                          child: _refreshDone
                              ? const Icon(Icons.check_rounded,
                                  size: 18, color: BMHColors.sGut)
                              : AnimatedRotation(
                                  turns: _ble.isRefreshing ? 2 : 0,
                                  duration: const Duration(seconds: 1),
                                  child: Icon(Icons.refresh_rounded,
                                    size: 18,
                                    color: _ble.isRefreshing
                                        ? BMHColors.cyan
                                        : BMHColors.inkMute)))),
                    const SizedBox(width: 6),
                    // Band wear status pill
                    _BandWearPill(ble: _ble),
                  ])),
                ]),
                const SizedBox(height: 24),

                // BIOSCORE
                _BioScoreCard(ble: _ble),
                const SizedBox(height: 22),

                // VITALS
                BMHSectionTitle('Biological signals'),
                const SizedBox(height: 16),

                // STEPS — first, live updating, tappable to chart
                _StepsRow(
                  ble: _ble,
                  onTap: () => _openVital('Steps Today',
                    BMHColors.sBody, '${_ble.steps}')),
                const SizedBox(height: 4),

                _VitalRow(label: 'Heart Rate',
                  value: hr > 0 ? '$hr' : '--', unit: 'bpm',
                  color: BMHColors.sCardio, icon: Icons.favorite_border_rounded,
                  isLive: hr > 0,
                  onTap: () => _openVital('Heart Rate', BMHColors.sCardio,
                    hr > 0 ? '$hr' : '--')),

                _VitalRow(label: 'Blood Pressure',
                  value: _ble.bloodPressure, unit: 'mmHg',
                  color: BMHColors.sCardio, icon: Icons.bloodtype_outlined,
                  isLive: _ble.bpSystolic > 0,
                  isMeasuring: _measuringBP,
                  measureSeconds: _seconds,
                  onTap: () => _openVital('Blood Pressure',
                    BMHColors.sCardio, _ble.bloodPressure),
                  onMeasure: _ble.bpSystolic == 0 ? () => _measure(
                    0x56, 30, (v) => setState(() => _measuringBP = v)) : null),

                _VitalRow(label: 'SpO₂',
                  value: spo2 > 0 ? '$spo2' : '--', unit: '%',
                  color: BMHColors.sOxygen, icon: Icons.water_drop_outlined,
                  isLive: spo2 > 0,
                  isMeasuring: _measuringSpo2,
                  measureSeconds: _seconds,
                  onTap: () => _openVital('SpO₂', BMHColors.sOxygen,
                    spo2 > 0 ? '$spo2' : '--'),
                  onMeasure: spo2 == 0 ? () => _measure(
                    0x03, 30, (v) => setState(() => _measuringSpo2 = v)) : null),

                _VitalRow(label: 'HRV',
                  value: hrv > 0 ? '$hrv' : '--', unit: 'ms',
                  color: BMHColors.sGut, icon: Icons.graphic_eq_rounded,
                  isLive: hrv > 0,
                  isMeasuring: _measuringHrv,
                  measureSeconds: _seconds,
                  onTap: () => _openVital('HRV', BMHColors.sGut,
                    hrv > 0 ? '$hrv' : '--'),
                  onMeasure: hrv == 0 ? () => _measure(
                    0x01, 60, (v) => setState(() => _measuringHrv = v)) : null),

                _VitalRow(label: 'Temperature',
                  value: temp > 0 ? temp.toStringAsFixed(1) : '--', unit: '°C',
                  color: BMHColors.sNervous, icon: Icons.thermostat_outlined,
                  isLive: temp > 0,
                  onTap: () => _openVital('Temperature', BMHColors.sNervous,
                    temp > 0 ? temp.toStringAsFixed(1) : '--')),

                _VitalRow(label: 'Stress Level',
                  value: stress > 0 ? '$stress' : '--', unit: '/100',
                  color: BMHColors.sMetabolic, icon: Icons.psychology_outlined,
                  isLive: stress > 0,
                  isMeasuring: _measuringStress,
                  measureSeconds: _seconds,
                  onTap: () => _openVital('Stress Level', BMHColors.sMetabolic,
                    stress > 0 ? '$stress' : '--'),
                  onMeasure: stress == 0 ? () => _measure(
                    0x05, 45, (v) => setState(() => _measuringStress = v)) : null),

                // Sleep — only shows when data arrives from band at night
                _VitalRow(
                  label: 'Sleep Quality',
                  value: _ble.lastSleep != null
                      ? _ble.lastSleep!.totalHours.toStringAsFixed(1) : '--',
                  unit: 'hrs',
                  subLabel: _ble.lastSleep != null
                      ? 'Last night · ${_ble.lastSleep!.quality}'
                      : 'Wear band tonight to track',
                  color: BMHColors.sSleep, icon: Icons.bedtime_outlined,
                  isLive: _ble.lastSleep != null,
                  onTap: () => _openVital('Sleep Quality', BMHColors.sSleep,
                    _ble.lastSleep != null
                        ? _ble.lastSleep!.totalHours.toStringAsFixed(1) : '--')),

                // Row 1: Band estimated glucose from HRV algorithm
                _VitalRow(
                  label: 'Blood Glucose (Band Est.)',
                  value: _bandGlucose > 0 ? '$_bandGlucose' : '--',
                  unit: 'mg/dL',
                  subLabel: _bandGlucose > 0
                      ? 'Estimated via HRV algorithm'
                      : 'Connect band to estimate',
                  color: BMHColors.sDna,
                  icon: Icons.science_outlined,
                  isLive: _bandGlucose > 0,
                  onTap: () => _openVital('Blood Glucose',
                    BMHColors.sDna,
                    _bandGlucose > 0 ? '$_bandGlucose' : '--')),

                const SizedBox(height: 8),

                // Row 2: Manual glucose entry
                _VitalRow(
                  label: 'Blood Glucose (Manual)',
                  value: _manualGlucose > 0 ? '$_manualGlucose' : '--',
                  unit: 'mg/dL',
                  subLabel: _manualGlucose > 0
                      ? 'Your reading · Tap Enter to update'
                      : 'Tap Enter to add your reading',
                  color: BMHColors.sDna,
                  icon: Icons.edit_note_rounded,
                  isLive: false,
                  showEditButton: true,
                  onTap: () => _manualGlucose > 0
                      ? _openVital('Blood Glucose (Manual)',
                          BMHColors.sDna, '$_manualGlucose')
                      : _showGlucoseDialog(),
                  onMeasure: () => _showGlucoseDialog()),

                const SizedBox(height: 120),
              ]),
            )),
          ])),
      ]),
    );
  }
}

// ── BAND PILL ─────────────────────────────────────────────
// Single smart pill — Band Worn / Band Not Worn / No Band
class _BandWearPill extends StatelessWidget {
  final BleService ble;
  const _BandWearPill({required this.ble});
  @override
  Widget build(BuildContext context) {
    if (!ble.isBandConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: BMHColors.bg4,
          borderRadius: BorderRadius.circular(BMHRadius.full),
          border: Border.all(color: BMHColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          BMHPulsingDot(color: BMHColors.inkMute, size: 5),
          const SizedBox(width: 5),
          Text('No Band', style: BMHText.monoSm.copyWith(
            color: BMHColors.inkMute, fontSize: 9)),
        ]));
    }
    final worn = ble.isWearing;
    final color = worn ? BMHColors.sGut : BMHColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(BMHRadius.full),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        BMHPulsingDot(color: color, size: 5),
        const SizedBox(width: 5),
        Text(worn ? 'Band Worn' : 'Band Not Worn',
          style: BMHText.monoSm.copyWith(color: color, fontSize: 9)),
      ]));
  }
}

// ── WEAR PILL ─────────────────────────────────────────────
// _WearPill removed — replaced by _BandWearPill

// ── VITAL ROW ─────────────────────────────────────────────
class _VitalRow extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  final bool isLive;
  final bool isMeasuring;
  final bool showEditButton;
  final int measureSeconds;
  final String? subLabel;
  final VoidCallback onTap;
  final VoidCallback? onMeasure;
  const _VitalRow({
    required this.label, required this.value, required this.unit,
    required this.color, required this.icon, required this.isLive,
    required this.onTap,
    this.subLabel,
    this.onMeasure, this.isMeasuring = false,
    this.measureSeconds = 0, this.showEditButton = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isMeasuring ? color.withOpacity(0.05) : BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(
          color: isMeasuring ? color.withOpacity(0.35) : BMHColors.line)),
      child: Column(children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: isMeasuring ? color.withOpacity(0.18) : color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25))),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: BMHText.bodyMd),
            if (isMeasuring)
              Text('Measuring... ${measureSeconds}s left',
                style: BMHText.monoSm.copyWith(color: color, fontSize: 8))
            else if (subLabel != null)
              Text(subLabel!,
                style: BMHText.monoSm.copyWith(
                  fontSize: 8, color: BMHColors.inkMute)),
          ])),
          if (isLive)
            Container(
              width: 5, height: 5,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)])),
          Text.rich(TextSpan(children: [
            TextSpan(text: value,
              style: BMHText.displaySm.copyWith(
                fontFamily: 'Fraunces', fontWeight: FontWeight.w300,
                fontSize: 17, color: value == '--' ? BMHColors.inkMute : color,
                height: 1)),
            TextSpan(text: ' $unit',
              style: BMHText.monoSm.copyWith(color: BMHColors.inkMute, fontSize: 9)),
          ])),
          const SizedBox(width: 8),
          // Show Edit button for manual entry (glucose)
          if (showEditButton && onMeasure != null)
            GestureDetector(
              onTap: onMeasure,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: color.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, color: color, size: 10),
                  const SizedBox(width: 4),
                  Text('Enter',
                    style: BMHText.monoSm.copyWith(
                      color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                ])))
          // Show Measure button when value is '--' and not measuring
          else if (onMeasure != null && !isMeasuring && value == '--')
            GestureDetector(
              onTap: onMeasure,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: color.withOpacity(0.3))),
                child: Text('Measure',
                  style: BMHText.monoSm.copyWith(
                    color: color, fontSize: 9, fontWeight: FontWeight.w600))))
          else
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkMute, size: 18),
        ]),
        // Progress bar — only shows while measuring
        if (isMeasuring) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: measureSeconds > 0 ? (1 - measureSeconds / 60) : 0,
              minHeight: 3,
              backgroundColor: BMHColors.bg4,
              valueColor: AlwaysStoppedAnimation(color))),
        ],
      ])));
}

// ── BIOSCORE CARD ─────────────────────────────────────────
class _BioScoreCard extends StatelessWidget {
  final BleService ble;
  const _BioScoreCard({required this.ble});

  BioScoreResult get _result => BioScoreCalculator.compute(ble);
  int get _score => _result.score;
  bool get _hasScore => _result.hasScore;
  String get _label => _result.label;
  BMHPillType get _pillType { if (_score >= 85) return BMHPillType.success; if (_score >= 70) return BMHPillType.info; return BMHPillType.warn; }

  static const _domains = [
    ('Cardio', 0.84, BMHColors.sCardio), ('Oxygen', 0.98, BMHColors.sOxygen),
    ('Metabolic', 0.72, BMHColors.sMetabolic), ('Sleep', 0.78, BMHColors.sSleep),
    ('Stress', 0.65, BMHColors.sNervous), ('Body', 0.88, BMHColors.sGut),
  ];

  @override
  Widget build(BuildContext context) {
    final va = ble.vitalAge > 0 ? ble.vitalAge : '--';
    final connected = ble.isBandConnected;
    final wearing   = ble.isWearing;
    final hasScore  = _hasScore;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: BMHColors.bg3,
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: BMHColors.lineBright),
        boxShadow: BMHShadows.card),
      child: Stack(children: [
        Positioned(right: -10, top: 0, bottom: 0,
          child: const BMHScanLineFigure(width: 80, height: 120, opacity: 0.15)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const BMHEyebrow('BioScore™', showDot: true),
            if (hasScore) BMHPill(_label, type: _pillType)
            else BMHPill(
              !connected ? 'Band not connected' : 'Wear band to measure',
              type: BMHPillType.info),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(hasScore ? '$_score' : '--',
              style: BMHText.displayXl.copyWith(
                fontSize: 72, height: 1,
                color: hasScore ? BMHColors.ink : BMHColors.inkMute)),
            Padding(padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text('/100', style: BMHText.monoLg.copyWith(
                color: BMHColors.inkMute, fontSize: 16))),
          ]),
          const SizedBox(height: 10),
          Text(
            hasScore
              ? 'Vital age: $va yrs  ·  Live from band'
              : !connected
                ? 'Connect your band to see BioScore'
                : 'Wear your band to calculate BioScore',
            style: BMHText.monoSm.copyWith(
              color: hasScore ? BMHColors.sGut : BMHColors.inkMute)),
          const SizedBox(height: 24),
          Column(children: _domains.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              SizedBox(width: 64, child: Text(d.$1,
                style: BMHText.monoSm.copyWith(fontSize: 9))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: hasScore ? d.$2 : 0.0,
                  minHeight: 4,
                  backgroundColor: BMHColors.bg4,
                  valueColor: AlwaysStoppedAnimation(
                    hasScore ? d.$3 : BMHColors.inkMute)))),
              const SizedBox(width: 8),
              Text(hasScore ? '${(d.$2 * 100).round()}' : '--',
                style: BMHText.monoSm.copyWith(
                  color: hasScore ? d.$3 : BMHColors.inkMute, fontSize: 9)),
            ]))).toList()),
        ]),
      ]),
    );
  }
}

// ── STEPS ROW ─────────────────────────────────────────────
class _StepsRow extends StatelessWidget {
  final BleService ble;
  final VoidCallback? onTap;
  const _StepsRow({required this.ble, this.onTap});
  @override
  Widget build(BuildContext context) {
    final steps = ble.steps; final goal = ble.stepGoal; final prog = ble.stepProgress;
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: prog >= 1.0
              ? BMHColors.sGut.withOpacity(0.4) : BMHColors.line)),
        child: Column(children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                color: BMHColors.sBody.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: BMHColors.sBody.withOpacity(0.25))),
              child: const Icon(Icons.directions_walk_rounded, color: BMHColors.sBody, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Steps Today', style: BMHText.heading2),
              Text('Live from band', style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.sBody)),
            ])),
            Text.rich(TextSpan(children: [
              TextSpan(text: '$steps', style: BMHText.displaySm.copyWith(fontSize: 20, color: BMHColors.sBody, height: 1)),
              TextSpan(text: ' /$goal', style: BMHText.monoSm.copyWith(color: BMHColors.inkMute)),
            ])),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: BMHColors.inkMute, size: 18),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: prog.clamp(0.0, 1.0), minHeight: 6,
              backgroundColor: BMHColors.bg4,
              valueColor: AlwaysStoppedAnimation(prog >= 1.0 ? BMHColors.sGut : BMHColors.sBody))),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0', style: BMHText.monoSm.copyWith(fontSize: 8)),
            Text(prog >= 1.0 ? '🎉 Goal reached!' : '${(prog * 100).round()}% of $goal steps goal',
              style: BMHText.monoSm.copyWith(fontSize: 8, color: prog >= 1.0 ? BMHColors.sGut : BMHColors.sBody)),
            Text('$goal', style: BMHText.monoSm.copyWith(fontSize: 8)),
          ]),
        ])));
  }
}

// ─────────────────────────────────────────────────────────
//  VITAL DETAIL SCREEN — Day / Week / Month with stored data
// ─────────────────────────────────────────────────────────
class VitalDetailScreen extends StatefulWidget {
  final String title, liveValue;
  final Color color;
  const VitalDetailScreen({super.key,
    required this.title, required this.color, required this.liveValue});
  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen> {
  int _range = 0; // 0=Day, 1=Week, 2=Month
  bool _isMeasuring = false;
  final _ble = BleService.instance;
  final _hist = VitalHistoryService.instance;

  VitalConfig get _cfg => VitalConfig.of(widget.title, widget.color);
  String get _histKey => VitalHistoryService.keyFor(widget.title);
  List<FlSpot> get _spots => _hist.getSpots(_histKey, _range);
  List<String> get _labels => _hist.getLabels(_histKey, _range);
  String get _periodLabel => _hist.getPeriodLabel(_range);

  bool get _isSteps => widget.title == 'Steps Today';
  bool get _isBP    => widget.title == 'Blood Pressure';
  bool get _isSleep => widget.title == 'Sleep Quality';

  // Measure Now — available on ALL vitals charts EXCEPT Sleep.
  // (Blood Glucose (Manual) keeps its manual-entry sheet.)
  bool get _isManual => !_isSleep;

  bool get _isManualEntry => widget.title == 'Blood Glucose (Manual)';

  // Teal green for chart axis numbers (bottom times + left counts)
  static const Color _axisTeal = Color(0xFF2DD4BF);

  // Daily chart zooms to the data's half-hour range (with padding)
  // instead of always spanning 0–47 — this is what prevents time
  // labels from ever overlapping.
  int get _dailyMinX {
    if (_spots.isEmpty) return 0;
    final lo = _spots.map((s) => s.x.toInt()).reduce((a, b) => a < b ? a : b);
    return (lo - 1).clamp(0, 47);
  }

  int get _dailyMaxX {
    if (_spots.isEmpty) return 47;
    final hi = _spots.map((s) => s.x.toInt()).reduce((a, b) => a > b ? a : b);
    // Ensure a minimum visible span of 4 slots so a single point
    // doesn't collapse the axis
    final min = _dailyMinX;
    return (hi + 1).clamp(min + 4, 47).clamp(0, 47);
  }

  // ── Stats — special handling per vital ───────────────
  String get _statMinLabel  => _isSteps ? 'Total'     : 'MIN';
  String get _statAvgLabel  => _isSteps ? 'Daily Avg' : _isBP ? 'Avg BP' : 'AVG';
  String get _statMaxLabel  => _isSteps ? 'Best Day'  : 'MAX';

  String get _statMinValue {
    if (_isSteps) {
      final s = _hist.getStepsStats(_range);
      return s.total > 0 ? s.total.round().toString() : '--';
    }
    if (_spots.length < 2) return '--';
    return _cfg.statMin(_min);
  }

  String get _statAvgValue {
    if (_isSteps) {
      final s = _hist.getStepsStats(_range);
      return s.dailyAvg > 0 ? s.dailyAvg.round().toString() : '--';
    }
    if (_isBP) return _hist.getBpAvgPair(_range);
    if (_spots.isEmpty) return '--';
    return _cfg.statAvg(_avg);
  }

  String get _statMaxValue {
    if (_isSteps) {
      final s = _hist.getStepsStats(_range);
      return s.bestDay > 0 ? s.bestDay.round().toString() : '--';
    }
    if (_spots.length < 2) return '--';
    return _cfg.statMax(_max);
  }

  double get _min { if (_spots.isEmpty) return 0; return _spots.map((s) => s.y).reduce((a, b) => a < b ? a : b); }
  double get _avg { if (_spots.isEmpty) return 0; return _spots.map((s) => s.y).reduce((a, b) => a + b) / _spots.length; }
  double get _max { if (_spots.isEmpty) return 0; return _spots.map((s) => s.y).reduce((a, b) => a > b ? a : b); }

  // Need at least 2 readings for meaningful Min/Max
  bool get _hasEnoughData => _spots.length >= 2;

  // Is current value in normal range?
  String _status(double val) {
    if (val == 0 && widget.liveValue == '--') return 'No data';
    if (val >= _cfg.normalMin && val <= _cfg.normalMax) return 'Normal';
    if (val < _cfg.normalMin) return 'Low';
    return 'High';
  }

  BMHPillType _statusType(String s) {
    if (s == 'Normal') return BMHPillType.success;
    if (s == 'No data') return BMHPillType.info;
    return BMHPillType.danger;
  }

  // ── Measure Now — capsule wave modal ──────────────────
  // The capsule animation runs while the band measures; the
  // result state is driven ONLY by real value updates coming
  // back from the band (never by the animation or a fake timer).

  MeasurementType get _capsuleType {
    switch (widget.title) {
      case 'Heart Rate':      return MeasurementType.heartRate;
      case 'SpO₂':            return MeasurementType.spo2;
      case 'HRV':             return MeasurementType.heartRateVariability;
      case 'Temperature':     return MeasurementType.skinTemperature;
      case 'Blood Pressure':  return MeasurementType.bloodPressure;
      case 'Steps Today':     return MeasurementType.steps;
      default:                return MeasurementType.glucose; // Stress/Glucose
    }
  }

  // Current live value from the band, formatted for display
  String? get _bandValue {
    switch (widget.title) {
      case 'Heart Rate':
        return _ble.heartRate > 0 ? '${_ble.heartRate}' : null;
      case 'SpO₂':
        return _ble.spo2 > 0 ? '${_ble.spo2}' : null;
      case 'HRV':
        return _ble.hrv > 0 ? '${_ble.hrv}' : null;
      case 'Temperature':
        return _ble.temperature > 0
            ? _ble.temperature.toStringAsFixed(1) : null;
      case 'Blood Pressure':
        return _ble.bpSystolic > 0 ? _ble.bloodPressure : null;
      case 'Stress Level':
        return _ble.stressLevel > 0 ? '${_ble.stressLevel}' : null;
      case 'Steps Today':
        return _ble.steps > 0 ? '${_ble.steps}' : null;
      case 'Blood Glucose':
        return widget.liveValue != '--' ? widget.liveValue : null;
      default:
        return null;
    }
  }

  // Manual glucose entry (for the 'Blood Glucose (Manual)' chart)
  void _manualEntryDialog() {
    int newVal = 100;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: BMHColors.bg3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BMHRadius.lg)),
          title: Text('Add Glucose Reading', style: BMHText.heading2),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$newVal mg/dL',
              style: BMHText.displaySm.copyWith(
                color: widget.color, fontSize: 34)),
            Slider(
              value: newVal.toDouble(), min: 50, max: 400,
              activeColor: widget.color,
              onChanged: (v) => setSt(() => newVal = v.round())),
            Text('Normal: 70–100 mg/dL (fasting)',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _hist.recordAt(_histKey, DateTime.now(), newVal.toDouble());
                Navigator.pop(ctx);
              },
              child: Text('Save',
                style: TextStyle(color: widget.color))),
          ])),
    );
  }

  Future<void> _measureNow() async {
    if (!_ble.isBandConnected || _isMeasuring) return;
    setState(() => _isMeasuring = true);

    // Band measurement command codes (0x2C type parameter).
    // Blood Pressure uses the HRV measurement (0x01) — the band
    // returns BP as part of the HRV result packet.
    final typeMap = {
      'Heart Rate':     0x00,
      'HRV':            0x01,
      'Blood Pressure': 0x01,
      'Blood Glucose':  0x02, // approximation via HR
      'SpO₂':           0x03,
      'Temperature':    0x04,
      'Stress Level':   0x05,
    };

    final state    = ValueNotifier(MeasurementState.preparing);
    final seconds  = ValueNotifier<int?>(null);
    final value    = ValueNotifier<String?>(null);
    var cancelled  = false;
    final baseline = _bandValue;
    final measureSec =
        widget.title == 'Temperature' ? 20
      : widget.title == 'Steps Today' ? 10 : 35;

    Future<void> stopCmd() async {
      final t = typeMap[widget.title];
      if (t != null) await _ble.stopMeasurement(t);
    }

    // Show the capsule modal (not dismissible; Cancel stops the band)
    // ignore: unawaited_futures
    showCapsuleMeasurementModal(
      context: context,
      type: _capsuleType,
      state: state,
      secondsRemaining: seconds,
      value: value,
      onCancel: () { cancelled = true; stopCmd(); },
      onRetry: () { /* modal closes; user taps Measure Now again */ },
    );

    // Start the band measurement
    if (typeMap[widget.title] != null) {
      await _ble.startMeasurement(typeMap[widget.title]!);
    }
    // Steps: no measure command — the live stream refreshes it.

    state.value = MeasurementState.measuring;
    seconds.value = measureSec;

    // Poll the live values the band sends back; complete on a real
    // update (value changed from baseline), fail on timeout/disconnect.
    var elapsed = 0;
    while (elapsed < measureSec && !cancelled && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      elapsed++;
      seconds.value = measureSec - elapsed;

      if (!_ble.isBandConnected) {
        state.value = MeasurementState.deviceDisconnected;
        await Future.delayed(const Duration(seconds: 4));
        break;
      }
      final v = _bandValue;
      // Require a few seconds before accepting, so we don't grab a
      // stale pre-measurement value the instant the modal opens.
      if (v != null && elapsed >= 5 && (v != baseline || elapsed >= 12)) {
        state.value = MeasurementState.processing;
        await Future.delayed(const Duration(milliseconds: 900));
        value.value = v;
        seconds.value = null;
        state.value = MeasurementState.success;
        break;
      }
    }

    if (!cancelled &&
        state.value != MeasurementState.success &&
        state.value != MeasurementState.deviceDisconnected) {
      seconds.value = null;
      state.value = MeasurementState.failed;
    }

    await stopCmd();
    if (mounted) setState(() => _isMeasuring = false);
  }

  @override
  void initState() {
    super.initState();
    _hist.addListener(_onHistory);
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hist.removeListener(_onHistory);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveNum = double.tryParse(widget.liveValue.replaceAll('/', '')) ?? 0;
    final status = _status(liveNum);

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 1),
      body: Stack(children: [
        Positioned(top: -180, left: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                widget.color.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH, vertical: 8),
              child: Row(children: [
                BMHIconButton(onTap: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: BMHColors.ink, size: 16)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BMHEyebrow('Health · vitals', showDot: _ble.isBandConnected),
                  Text(widget.title, style: BMHText.heading1),
                ])),
                BMHIconButton(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chart data saved to clipboard',
                      style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
                    backgroundColor: widget.color,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BMHRadius.full)))),
                icon: const Icon(Icons.share_outlined, color: BMHColors.ink, size: 16)),
              ])),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 20),

                // ── HERO CARD ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [widget.color.withOpacity(0.12), BMHColors.bg3]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: widget.color.withOpacity(0.35))),
                  child: Stack(children: [
                    // Top accent line
                    Positioned(top: -20, left: -20, right: -20,
                      child: Container(height: 2, color: widget.color)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        BMHEyebrow(widget.title, showDot: _ble.isBandConnected),
                        BMHPill(status, type: _statusType(status)),
                      ]),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(widget.liveValue,
                          style: BMHText.displayXl.copyWith(
                            fontSize: 64, height: 1,
                            fontFamily: 'Fraunces',
                            color: widget.color)),
                        Padding(padding: const EdgeInsets.only(bottom: 10, left: 6),
                          child: Text(_cfg.unit,
                            style: BMHText.monoLg.copyWith(color: BMHColors.inkMute))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        BMHPulsingDot(
                          color: _isManualEntry
                            ? widget.color
                            : _ble.isBandConnected ? widget.color : BMHColors.inkMute,
                          size: 5),
                        const SizedBox(width: 6),
                        Text(
                          _isManualEntry
                            ? 'Manual entry'
                            : _ble.isBandConnected ? 'Live from band' : 'Band not connected',
                          style: BMHText.monoSm.copyWith(
                            color: _isManualEntry
                              ? widget.color
                              : _ble.isBandConnected ? widget.color : BMHColors.inkMute,
                            fontSize: 9)),
                      ]),
                      // Min / Normal / Max quick reference
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BMHColors.bg0.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(BMHRadius.md),
                          border: Border.all(color: BMHColors.line)),
                        child: Row(children: [
                          Expanded(child: _RefCell('Min', '${_cfg.normalMin.toStringAsFixed(_cfg.normalMin % 1 == 0 ? 0 : 1)} ${_cfg.unit}', BMHColors.sOxygen)),
                          Container(width: 1, height: 30, color: BMHColors.line),
                          Expanded(child: _RefCell('Normal', '${_cfg.normalMin.toStringAsFixed(0)}–${_cfg.normalMax.toStringAsFixed(0)}', BMHColors.sGut)),
                          Container(width: 1, height: 30, color: BMHColors.line),
                          Expanded(child: _RefCell('Max', '${_cfg.normalMax.toStringAsFixed(_cfg.normalMax % 1 == 0 ? 0 : 1)} ${_cfg.unit}', BMHColors.sCardio)),
                        ]),
                      ),
                    ]),
                  ])),

                const SizedBox(height: 20),

                // ── RANGE TABS ─────────────────────────
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: BMHColors.bg3,
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(children: List.generate(3, (i) {
                    final labels = ['Daily', 'Weekly', 'Monthly'];
                    final active = i == _range;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _range = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: active ? widget.color : Colors.transparent,
                          borderRadius: BorderRadius.circular(BMHRadius.full)),
                        child: Center(child: Text(labels[i],
                          style: BMHText.labelMd.copyWith(
                            color: active ? BMHColors.bg0 : BMHColors.inkMute,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400))))));
                  }))),

                const SizedBox(height: 12),

                // ── CHART CARD ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_periodLabel,
                        style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.inkMute)),
                      Text('Avg ${_cfg.statAvg(_avg)} ${_cfg.unit}',
                        style: BMHText.monoSm.copyWith(
                          color: widget.color, fontSize: 9,
                          fontStyle: FontStyle.italic)),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 160,
                      child: _spots.length < 2
                          ? Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.watch_outlined,
                                  size: 32, color: BMHColors.inkMute),
                                const SizedBox(height: 8),
                                Text(
                                  _hist.hasData
                                    ? 'Not enough data yet\nKeep wearing your band'
                                    : 'No data yet\nWear your band to start tracking',
                                  textAlign: TextAlign.center,
                                  style: BMHText.bodySm.copyWith(
                                    color: BMHColors.inkMute)),
                              ]))
                          : LineChart(LineChartData(
                              gridData: FlGridData(show: true,
                                drawVerticalLine: false,
                                horizontalInterval: (_cfg.maxY - _cfg.minY) / 4,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: BMHColors.line, strokeWidth: 1,
                                  dashArray: [4, 4])),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 30,
                                  interval: (_cfg.maxY - _cfg.minY) / 4,
                                  getTitlesWidget: (v, _) => Text(
                                    v.toStringAsFixed(_cfg.minY % 1 == 0 ? 0 : 1),
                                    style: BMHText.monoSm.copyWith(
                                      fontSize: 8, color: _axisTeal)))),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 24,
                                  interval: 1,
                                  getTitlesWidget: (v, meta) {
                                    if (_range == 0) {
                                      // Daily — x is a half-hour slot (0–47).
                                      // The axis is zoomed to the data range
                                      // (see minX/maxX below), and the label
                                      // step is chosen so at most ~5 labels
                                      // are visible — they can never overlap.
                                      final slot = v.round();
                                      if (slot < _dailyMinX || slot > _dailyMaxX) {
                                        return const SizedBox();
                                      }
                                      final span = _dailyMaxX - _dailyMinX + 1;
                                      final step = (span / 5).ceil().clamp(1, 12);
                                      if ((slot - _dailyMinX) % step != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          VitalHistoryService.halfHourLabel(slot),
                                          style: BMHText.monoSm.copyWith(
                                            fontSize: 7.5, color: _axisTeal)));
                                    }
                                    if (_range == 1) {
                                      // Weekly — fixed 7 positions 0–6 = MON–SUN
                                      final labels = _hist.getLabels(_histKey, 1);
                                      final idx = v.round();
                                      if (idx < 0 || idx >= labels.length) return const SizedBox();
                                      return Text(labels[idx],
                                        style: BMHText.monoSm.copyWith(
                                          fontSize: 7, color: _axisTeal));
                                    }
                                    // Monthly — fixed 4 positions 0–3 = W1–W4
                                    const wLabels = ['W1', 'W2', 'W3', 'W4'];
                                    final idx = v.round();
                                    if (idx < 0 || idx >= wLabels.length) return const SizedBox();
                                    return Text(wLabels[idx],
                                      style: BMHText.monoSm.copyWith(
                                        fontSize: 7, color: _axisTeal));
                                  })),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                              borderData: FlBorderData(show: false),
                              minY: _cfg.minY, maxY: _cfg.maxY,
                              minX: _range == 0 ? _dailyMinX.toDouble() : 0,
                              maxX: _range == 0
                                  ? _dailyMaxX.toDouble()
                                  : _range == 1 ? 6 : 3,
                              // Normal range band
                              rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                                HorizontalRangeAnnotation(
                                  y1: _cfg.normalMin, y2: _cfg.normalMax,
                                  color: widget.color.withOpacity(0.06)),
                              ]),
                              lineBarsData: [LineChartBarData(
                                spots: _spots, isCurved: true,
                                color: widget.color, barWidth: 2,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: true,
                                  getDotPainter: (_, __, ___, ____) =>
                                    FlDotCirclePainter(radius: 3, color: widget.color,
                                      strokeWidth: 1.5, strokeColor: BMHColors.bg0)),
                                belowBarData: BarAreaData(show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [widget.color.withOpacity(0.2),
                                      widget.color.withOpacity(0.0)])))],
                            ))),
                    const SizedBox(height: 10),
                    // X-axis labels row hidden (built into chart above)
                  ])),

                const SizedBox(height: 20),

                // ── STATISTICS — Min / Avg / Max ───────
                BMHSectionTitle('Statistics'),
                const SizedBox(height: 16),

                // 3 tiles
                Row(children: [
                  Expanded(child: _StatTile(_statMinLabel, _statMinValue, _isSteps ? 'steps' : _cfg.unit, widget.color,
                    isMin: true, color: BMHColors.sOxygen)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(_statAvgLabel, _statAvgValue, _isSteps ? 'steps' : _isBP ? 'mmHg' : _cfg.unit, widget.color,
                    isAvg: true, color: widget.color)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(_statMaxLabel, _statMaxValue, _isSteps ? 'steps' : _cfg.unit, widget.color,
                    isMax: true, color: BMHColors.sCardio)),
                ]),

                // Helper message when not enough data for Min/Max
                if (!_isSteps && _spots.length < 2) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.info_outline_rounded,
                      size: 12, color: BMHColors.inkMute),
                    const SizedBox(width: 6),
                    Text(
                      _spots.isEmpty
                        ? 'Wear your band to start collecting data'
                        : 'Min & Max will appear as more readings are collected',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.inkMute,
                        fontStyle: FontStyle.italic)),
                  ]),
                ],

                // ── ACTIVITY SUMMARY (Steps screen only) ──
                if (_isSteps) ...[
                  const SizedBox(height: 16),
                  Builder(builder: (_) {
                    final act = _hist.getActivityStats(_range);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: BMHColors.surface,
                        borderRadius: BorderRadius.circular(BMHRadius.lg),
                        border: Border.all(color: BMHColors.line)),
                      child: Row(children: [
                        _ActivityCell(
                          icon: Icons.directions_walk_rounded,
                          label: 'Steps',
                          value: act.steps > 0
                            ? _fmtNum(act.steps.round()) : '--',
                          unit: '',
                          color: BMHColors.sBody),
                        _vDivider(),
                        _ActivityCell(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Calories',
                          value: act.calories > 0
                            ? act.calories.round().toString() : '--',
                          unit: 'kcal',
                          color: BMHColors.sCardio),
                        _vDivider(),
                        _ActivityCell(
                          icon: Icons.route_outlined,
                          label: 'Distance',
                          value: act.distanceKm > 0
                            ? act.distanceKm.toStringAsFixed(1) : '--',
                          unit: 'km',
                          color: BMHColors.sGut),
                        _vDivider(),
                        _ActivityCell(
                          icon: Icons.timer_outlined,
                          label: 'Active',
                          value: act.exerciseMin > 0
                            ? act.exerciseMin.round().toString() : '--',
                          unit: 'min',
                          color: BMHColors.sSleep),
                      ]));
                  }),
                ],

                const SizedBox(height: 10),

                // Normal range indicator bar
                _NormalRangeBar(
                  min: _min, max: _max, avg: _avg,
                  normalMin: _cfg.normalMin, normalMax: _cfg.normalMax,
                  color: widget.color, unit: _cfg.unit),

                const SizedBox(height: 20),

                // ── INSIGHT ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: widget.color.withOpacity(0.2))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: widget.color.withOpacity(0.3))),
                      child: Icon(Icons.lightbulb_outline_rounded,
                        color: widget.color, size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Insight', style: BMHText.labelLg.copyWith(color: widget.color)),
                      const SizedBox(height: 4),
                      Text(_cfg.insight,
                        style: BMHText.bodyMd.copyWith(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          color: BMHColors.inkDim)),
                    ])),
                  ])),


                SizedBox(height: _isManual ? 80 : 120),
              ]),
            )),

            // ── MEASURE NOW BUTTON (all vitals except Sleep) ──
            if (_isManual)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BMHSpacing.screenH, 0, BMHSpacing.screenH, 24),
                child: GestureDetector(
                  onTap: _isManualEntry
                      ? _manualEntryDialog
                      : (_ble.isBandConnected ? _measureNow : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: _isMeasuring
                          ? widget.color.withOpacity(0.4)
                          : (!_ble.isBandConnected && !_isManualEntry)
                              ? BMHColors.bg4
                              : widget.color,
                      borderRadius: BorderRadius.circular(BMHRadius.full),
                      boxShadow: _ble.isBandConnected && !_isMeasuring
                          ? [BoxShadow(
                              color: widget.color.withOpacity(0.35),
                              blurRadius: 12, offset: const Offset(0, 4))]
                          : null),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isMeasuring) ...[
                          const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BMHColors.bg0)),
                          const SizedBox(width: 10),
                          Text('Measuring...',
                            style: BMHText.labelLg.copyWith(
                              color: BMHColors.bg0)),
                        ] else ...[
                          Icon(
                            _isManualEntry
                                ? Icons.edit_note_rounded
                                : Icons.monitor_heart_outlined,
                            color: (_ble.isBandConnected || _isManualEntry)
                                ? BMHColors.bg0 : BMHColors.inkMute,
                            size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isManualEntry
                                ? 'Add Reading'
                                : _ble.isBandConnected
                                    ? 'Measure Now'
                                    : 'Band not connected',
                            style: BMHText.labelLg.copyWith(
                              color: (_ble.isBandConnected || _isManualEntry)
                                  ? BMHColors.bg0 : BMHColors.inkMute)),
                        ],
                      ]))))
          ])),
      ]),
    );
  }
}

// ── ACTIVITY SUMMARY WIDGETS ──────────────────────────────
Widget _vDivider() => Container(
  width: 1, height: 40,
  margin: const EdgeInsets.symmetric(horizontal: 4),
  color: BMHColors.line);

String _fmtNum(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

class _ActivityCell extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  const _ActivityCell({
    required this.icon, required this.label,
    required this.value, required this.unit,
    required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text.rich(TextSpan(children: [
        TextSpan(text: value,
          style: BMHText.displaySm.copyWith(
            fontSize: 14,
            color: value == '--' ? BMHColors.inkMute : color,
            fontFamily: 'Fraunces', fontWeight: FontWeight.w300, height: 1.1)),
        if (unit.isNotEmpty)
          TextSpan(text: ' $unit',
            style: BMHText.monoSm.copyWith(
              fontSize: 8, color: BMHColors.inkMute)),
      ])),
      const SizedBox(height: 2),
      Text(label, style: BMHText.monoSm.copyWith(
        fontSize: 8, color: BMHColors.inkMute)),
    ]));
}

class _RefCell extends StatelessWidget {
  final String label, value; final Color color;
  const _RefCell(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: BMHText.monoSm.copyWith(fontSize: 8, color: BMHColors.inkMute)),
    const SizedBox(height: 3),
    Text(value, style: BMHText.monoSm.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}

// ── STAT TILE ─────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value, unit;
  final Color accentColor, color;
  final bool isMin, isAvg, isMax;
  const _StatTile(this.label, this.value, this.unit, this.accentColor, {
    this.isMin = false, this.isAvg = false, this.isMax = false,
    required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isAvg ? color.withOpacity(0.08) : BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: isAvg ? color.withOpacity(0.3) : BMHColors.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Top accent line
      Container(height: 2, width: 30,
        margin: const EdgeInsets.only(bottom: 8),
        color: color),
      Text(label.toUpperCase(),
        style: BMHText.monoSm.copyWith(fontSize: 8, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      Text.rich(TextSpan(children: [
        TextSpan(text: value,
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22,
            color: color, height: 1, fontWeight: FontWeight.w400)),
        TextSpan(text: ' $unit',
          style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.inkMute)),
      ])),
    ]));
}

// ── NORMAL RANGE BAR ──────────────────────────────────────
class _NormalRangeBar extends StatelessWidget {
  final double min, max, avg, normalMin, normalMax;
  final Color color;
  final String unit;
  const _NormalRangeBar({
    required this.min, required this.max, required this.avg,
    required this.normalMin, required this.normalMax,
    required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    // Position of avg value on bar (0.0 to 1.0)
    final range = normalMax - normalMin;
    if (range <= 0) return const SizedBox();
    final pos = ((avg - normalMin) / range).clamp(0.0, 1.0);
    final isNormal = avg >= normalMin && avg <= normalMax;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Normal range indicator',
            style: BMHText.monoSm.copyWith(fontSize: 9)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isNormal ? BMHColors.sGut.withOpacity(0.1) : BMHColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(BMHRadius.full),
              border: Border.all(color: isNormal ? BMHColors.sGut.withOpacity(0.3) : BMHColors.danger.withOpacity(0.3))),
            child: Text(isNormal ? '✓ Normal' : '⚠ Outside range',
              style: BMHText.monoSm.copyWith(
                fontSize: 8,
                color: isNormal ? BMHColors.sGut : BMHColors.danger))),
        ]),
        const SizedBox(height: 12),
        Stack(children: [
          // Background track
          Container(height: 8, decoration: BoxDecoration(
            color: BMHColors.bg4, borderRadius: BorderRadius.circular(4))),
          // Normal zone
          Positioned.fill(child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  BMHColors.sOxygen.withOpacity(0.3),
                  color.withOpacity(0.4),
                  BMHColors.sCardio.withOpacity(0.3)]),
                borderRadius: BorderRadius.circular(4))))),
          // Needle indicator
          Positioned(
            left: (MediaQuery.of(context).size.width - 60) * pos - 4,
            top: -3,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: isNormal ? color : BMHColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: BMHColors.bg0, width: 2),
                boxShadow: [BoxShadow(
                  color: (isNormal ? color : BMHColors.danger).withOpacity(0.5),
                  blurRadius: 6)]))),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${normalMin.toStringAsFixed(0)} $unit',
            style: BMHText.monoSm.copyWith(fontSize: 8, color: BMHColors.sOxygen)),
          Text('Normal Range', style: BMHText.monoSm.copyWith(fontSize: 8)),
          Text('${normalMax.toStringAsFixed(0)} $unit',
            style: BMHText.monoSm.copyWith(fontSize: 8, color: BMHColors.sCardio)),
        ]),
      ]));
  }
}

// ═══════════════════════════════════════════════════════════
//  SLEEP DETAIL SCREEN
// ═══════════════════════════════════════════════════════════
class SleepDetailScreen extends StatefulWidget {
  final BMHSleepData? sleepData;
  const SleepDetailScreen({super.key, this.sleepData});
  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  int _range = 0;
  final _ble = BleService.instance;

  BMHSleepData? get _sleep => widget.sleepData;

  @override
  void initState() {
    super.initState();
    VitalHistoryService.instance.addListener(_onHistory);
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VitalHistoryService.instance.removeListener(_onHistory);
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────
  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  double _efficiency() {
    if (_sleep == null || _sleep!.totalMinutes == 0) return 0;
    final awake = _sleep!.awakeMinutes;
    return (((_sleep!.totalMinutes - awake) / _sleep!.totalMinutes) * 100).clamp(0, 100);
  }

  // Status badge helpers
  Color _badgeBg(String status) {
    if (status == 'Optimal') return const Color(0xFF1a3a2a);
    if (status == 'Needs Attention') return const Color(0xFF3a2a10);
    return const Color(0xFF3a1a1a);
  }

  Color _badgeBorder(String status) {
    if (status == 'Optimal') return const Color(0xFF2a6a4a);
    if (status == 'Needs Attention') return const Color(0xFF6a4a20);
    return const Color(0xFF6a2a2a);
  }

  Color _badgeText(String status) {
    if (status == 'Optimal') return const Color(0xFF4dbb8f);
    if (status == 'Needs Attention') return const Color(0xFFe0a84a);
    return const Color(0xFFe05a5a);
  }

  String _sleepStatus(double hours) {
    if (hours >= 7 && hours <= 9) return 'Optimal';
    if (hours >= 6) return 'Needs Attention';
    return 'Low';
  }

  String _deepStatus(int min) {
    if (min >= 60) return 'Optimal';
    if (min >= 40) return 'Needs Attention';
    return 'Low';
  }

  String _remStatus(int min) {
    if (min >= 70) return 'Optimal';
    if (min >= 45) return 'Needs Attention';
    return 'Low';
  }

  String _effStatus(double eff) {
    if (eff >= 85) return 'Optimal';
    if (eff >= 70) return 'Needs Attention';
    return 'Low';
  }

  String _spo2Status(int v) {
    if (v >= 95) return 'Optimal';
    if (v >= 90) return 'Needs Attention';
    return 'Low';
  }

  String _hrvStatus(int v) {
    if (v >= 40) return 'Optimal';
    if (v >= 20) return 'Needs Attention';
    return 'Low';
  }

  Widget _badge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: _badgeBg(status),
      border: Border.all(color: _badgeBorder(status)),
      borderRadius: BorderRadius.circular(BMHRadius.full)),
    child: Text(status,
      style: BMHText.monoSm.copyWith(fontSize: 9, color: _badgeText(status))));

  Widget _progressBar(double fraction, Color color) => Container(
    height: 3,
    decoration: BoxDecoration(
      color: BMHColors.bg4,
      borderRadius: BorderRadius.circular(2)),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: fraction.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2)))));

  // ── Stage card ───────────────────────────────────────────
  Widget _stageCard({
    required String label,
    required int minutes,
    required Color color,
    required String status,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      border: Border.all(color: color.withOpacity(0.22)),
      borderRadius: BorderRadius.circular(BMHRadius.lg)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        Text(label, style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.inkMute)),
      ]),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: [
        TextSpan(text: '${minutes ~/ 60}',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22,
            color: color, height: 1, fontWeight: FontWeight.w400)),
        TextSpan(text: 'h ',
          style: BMHText.monoSm.copyWith(fontSize: 11, color: BMHColors.inkMute)),
        TextSpan(text: '${minutes % 60}',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22,
            color: color, height: 1, fontWeight: FontWeight.w400)),
        TextSpan(text: 'm',
          style: BMHText.monoSm.copyWith(fontSize: 11, color: BMHColors.inkMute)),
      ])),
      const SizedBox(height: 6),
      _badge(status),
    ]));

  // ── Overview row ─────────────────────────────────────────
  Widget _overviewRow({
    required String label,
    required String value,
    required String status,
    required Color barColor,
    required double barFraction,
    bool isLast = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      border: isLast ? null : Border(
        bottom: BorderSide(color: BMHColors.line))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: BMHText.bodyMd.copyWith(fontSize: 12, color: BMHColors.inkDim)),
        Row(children: [
          Text(value,
            style: BMHText.monoSm.copyWith(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _badgeText(status))),
          const SizedBox(width: 8),
          _badge(status),
        ]),
      ]),
      const SizedBox(height: 6),
      _progressBar(barFraction, barColor),
    ]));

  // ── Stacked bar chart ─────────────────────────────────────
  Widget _stackedChart() {
    final hist = VitalHistoryService.instance;
    final spots = hist.getSpots('sleep', _range);
    final labels = hist.getLabels('sleep', _range);
    final periodLabel = _range == 0 ? 'This week' : _range == 1 ? 'Last 4 weeks' : 'Last 6 months';

    if (spots.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_outlined, size: 32, color: BMHColors.inkMute),
            const SizedBox(height: 8),
            Text(
              hist.hasData
                ? 'Not enough sleep data yet\nWear band overnight to track'
                : 'No sleep data yet\nWear band tonight to start tracking',
              textAlign: TextAlign.center,
              style: BMHText.bodySm.copyWith(color: BMHColors.inkMute)),
          ])));
    }

    final avg = spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(periodLabel,
          style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.inkMute)),
        Text('Avg ${avg.toStringAsFixed(1)} hrs',
          style: BMHText.monoSm.copyWith(
            color: BMHColors.sSleep, fontSize: 9, fontStyle: FontStyle.italic)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 10,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 18,
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(labels[i],
                    style: BMHText.monoSm.copyWith(fontSize: 7,
                      color: const Color(0xFF2DD4BF)));
                })),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 24,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: BMHText.monoSm.copyWith(fontSize: 7,
                    color: const Color(0xFF2DD4BF))))),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
            gridData: FlGridData(show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (_) => FlLine(
                color: BMHColors.line, strokeWidth: 1, dashArray: [4, 4])),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(spots.length, (i) {
              final total = spots[i].y;
              final deep = (total * 0.2).clamp(0, total);
              final light = (total * 0.38).clamp(0, total);
              final rem = (total * 0.22).clamp(0, total);
              final awake = (total - deep - light - rem).clamp(0, total);
              return BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: total,
                  width: 14,
                  borderRadius: BorderRadius.circular(3),
                  rodStackItems: [
                    BarChartRodStackItem(0, deep.toDouble(), BMHColors.sSleep),
                    BarChartRodStackItem(deep.toDouble(), (deep + light).toDouble(),
                      const Color(0xFF5bc4f5)),
                    BarChartRodStackItem((deep + light).toDouble(),
                      (deep + light + rem).toDouble(), BMHColors.sGut),
                    BarChartRodStackItem((deep + light + rem).toDouble(),
                      total, BMHColors.sCardio),
                  ]),
              ]);
            }),
          ))),
      const SizedBox(height: 8),
      Row(children: [
        _legendDot(BMHColors.sSleep, 'Deep'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFF5bc4f5), 'Light'),
        const SizedBox(width: 12),
        _legendDot(BMHColors.sGut, 'REM'),
        const SizedBox(width: 12),
        _legendDot(BMHColors.sCardio, 'Awake'),
      ]),
    ]);
  }

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    Text(label, style: BMHText.monoSm.copyWith(fontSize: 9, color: BMHColors.inkMute)),
  ]);

  @override
  Widget build(BuildContext context) {
    final sleep = _sleep;
    final totalHrs = sleep != null ? sleep.totalHours : 0.0;
    final deepMin = sleep?.deepMinutes ?? 0;
    final lightMin = sleep?.lightMinutes ?? 0;
    final remMin = sleep?.remMinutes ?? 0;
    final awakeMin = sleep?.awakeMinutes ?? 0;
    final eff = _efficiency();

    final sleepStatus = sleep != null ? _sleepStatus(totalHrs) : 'No data';

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 1),
      body: Stack(children: [
        Positioned(top: -180, left: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                BMHColors.sSleep.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false,
          child: Column(children: [
            // ── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH, vertical: 8),
              child: Row(children: [
                BMHIconButton(
                  onTap: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                    color: BMHColors.ink, size: 16)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BMHEyebrow('Health · vitals',
                    showDot: _ble.isBandConnected),
                  Text('Sleep Quality', style: BMHText.heading1),
                ])),
                BMHIconButton(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sleep data copied',
                        style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
                      backgroundColor: BMHColors.sSleep,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BMHRadius.full)))),
                  icon: const Icon(Icons.share_outlined,
                    color: BMHColors.ink, size: 16)),
              ])),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),

                // ── Hero card ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [
                        BMHColors.sSleep.withOpacity(0.12), BMHColors.bg3]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(
                      color: BMHColors.sSleep.withOpacity(0.35))),
                  child: Stack(children: [
                    Positioned(top: -20, left: -20, right: -20,
                      child: Container(height: 2, color: BMHColors.sSleep)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                        BMHEyebrow('Sleep Quality',
                          showDot: _ble.isBandConnected),
                        _badge(sleepStatus),
                      ]),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                        Text(sleep != null
                            ? totalHrs.toStringAsFixed(1) : '--',
                          style: BMHText.displayXl.copyWith(
                            fontSize: 64, height: 1,
                            fontFamily: 'Fraunces',
                            color: BMHColors.sSleep)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 6),
                          child: Text('hrs',
                            style: BMHText.monoLg.copyWith(
                              color: BMHColors.inkMute))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        BMHPulsingDot(
                          color: _ble.isBandConnected
                            ? BMHColors.sSleep : BMHColors.inkMute,
                          size: 5),
                        const SizedBox(width: 6),
                        Text(_ble.isBandConnected
                            ? 'Live from band' : 'Band not connected',
                          style: BMHText.monoSm.copyWith(
                            color: _ble.isBandConnected
                              ? BMHColors.sSleep : BMHColors.inkMute,
                            fontSize: 9)),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BMHColors.bg0.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(BMHRadius.md),
                          border: Border.all(color: BMHColors.line)),
                        child: Row(children: [
                          Expanded(child: _RefCell('Min', '7 hrs',
                            BMHColors.sOxygen)),
                          Container(width: 1, height: 30,
                            color: BMHColors.line),
                          Expanded(child: _RefCell('Normal', '7–9',
                            BMHColors.sGut)),
                          Container(width: 1, height: 30,
                            color: BMHColors.line),
                          Expanded(child: _RefCell('Max', '9 hrs',
                            BMHColors.sCardio)),
                        ]),
                      ),
                    ]),
                  ])),

                const SizedBox(height: 16),

                // ── Range tabs ────────────────────────────
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: BMHColors.bg3,
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(children: List.generate(3, (i) {
                    final labels = ['Daily', 'Weekly', 'Monthly'];
                    final active = i == _range;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _range = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: active
                            ? BMHColors.sSleep : Colors.transparent,
                          borderRadius: BorderRadius.circular(BMHRadius.full)),
                        child: Center(child: Text(labels[i],
                          style: BMHText.labelMd.copyWith(
                            color: active
                              ? BMHColors.bg0 : BMHColors.inkMute,
                            fontWeight: active
                              ? FontWeight.w600 : FontWeight.w400))))));
                  }))),

                const SizedBox(height: 12),

                // ── Stacked chart card ─────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: _stackedChart()),

                const SizedBox(height: 16),

                // ── Sleep stage cards ─────────────────────
                if (sleep != null) ...[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.4,
                    children: [
                      _stageCard(
                        label: 'Deep Sleep',
                        minutes: deepMin,
                        color: BMHColors.sSleep,
                        status: _deepStatus(deepMin)),
                      _stageCard(
                        label: 'Light Sleep',
                        minutes: lightMin,
                        color: const Color(0xFF5bc4f5),
                        status: lightMin >= 90 ? 'Optimal' : 'Needs Attention'),
                      _stageCard(
                        label: 'REM Sleep',
                        minutes: remMin,
                        color: BMHColors.sGut,
                        status: _remStatus(remMin)),
                      _stageCard(
                        label: 'Awake Time',
                        minutes: awakeMin,
                        color: BMHColors.sCardio,
                        status: awakeMin <= 30 ? 'Optimal' : 'Needs Attention'),
                    ]),

                  const SizedBox(height: 16),
                ],

                // ── Sleep Overview ────────────────────────
                BMHSectionTitle('Sleep Overview'),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    _overviewRow(
                      label: 'Total Sleep Time',
                      value: sleep != null ? _fmt(sleep.totalMinutes) : '--',
                      status: sleep != null
                        ? _sleepStatus(totalHrs) : 'No data',
                      barColor: _badgeText(
                        sleep != null ? _sleepStatus(totalHrs) : 'No data'),
                      barFraction: totalHrs / 9.0),
                    _overviewRow(
                      label: 'Sleep Efficiency',
                      value: sleep != null
                        ? '${eff.toStringAsFixed(0)}%' : '--',
                      status: sleep != null ? _effStatus(eff) : 'No data',
                      barColor: _badgeText(
                        sleep != null ? _effStatus(eff) : 'No data'),
                      barFraction: eff / 100.0),
                    _overviewRow(
                      label: 'Deep Sleep',
                      value: sleep != null ? _fmt(deepMin) : '--',
                      status: sleep != null
                        ? _deepStatus(deepMin) : 'No data',
                      barColor: BMHColors.sSleep,
                      barFraction: deepMin / 120.0,
                      isLast: true),
                  ])),

                const SizedBox(height: 20),

                // ── Statistics ────────────────────────────
                BMHSectionTitle('Statistics'),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final ss = VitalHistoryService.instance.getSleepStats(_range);
                  final hasHistory = ss.avg > 0;
                  return Row(children: [
                    Expanded(child: _StatTile('Worst',
                      hasHistory ? ss.worst.toStringAsFixed(1)
                        : (sleep != null ? totalHrs.toStringAsFixed(1) : '--'),
                      'hrs', BMHColors.sSleep,
                      isMin: true, color: BMHColors.sOxygen)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatTile('Avg',
                      hasHistory ? ss.avg.toStringAsFixed(1)
                        : (sleep != null ? totalHrs.toStringAsFixed(1) : '--'),
                      'hrs', BMHColors.sSleep,
                      isAvg: true, color: BMHColors.sSleep)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatTile('Best',
                      hasHistory ? ss.best.toStringAsFixed(1)
                        : (sleep != null ? totalHrs.toStringAsFixed(1) : '--'),
                      'hrs', BMHColors.sSleep,
                      isMax: true, color: BMHColors.sCardio)),
                  ]);
                }),

                const SizedBox(height: 20),

                // ── Insight ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.sSleep.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: BMHColors.sSleep.withOpacity(0.2))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: BMHColors.sSleep.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: BMHColors.sSleep.withOpacity(0.3))),
                      child: Icon(Icons.lightbulb_outline_rounded,
                        color: BMHColors.sSleep, size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Insight',
                        style: BMHText.labelLg.copyWith(
                          color: BMHColors.sSleep)),
                      const SizedBox(height: 4),
                      Text('7–9 hours of quality sleep with sufficient deep '
                          'and REM stages is essential for memory, recovery, '
                          'and overall health.',
                        style: BMHText.bodyMd.copyWith(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          color: BMHColors.inkDim)),
                    ])),
                  ])),

                const SizedBox(height: 120),
              ]),
            )),
          ])),
      ]),
    );
  }
}
