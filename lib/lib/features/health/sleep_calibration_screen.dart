// ─────────────────────────────────────────────────────────
//  SLEEP CALIBRATION
//
//  Shows the RAW numbers the band sent last night, before any
//  interpretation. Open this screen after an overnight sync, take a
//  screenshot, and compare it side by side with the JCVital app's
//  deep / light / awake figures for the same night.
//
//  Once we know what the raw values mean on your hardware, the
//  constants in sleep_analyzer.dart can be fixed permanently and the
//  automatic detection removed.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/ble/ble_service.dart';
import '../../core/health/sleep_analyzer.dart';

class SleepCalibrationScreen extends StatefulWidget {
  const SleepCalibrationScreen({super.key});

  @override
  State<SleepCalibrationScreen> createState() =>
      _SleepCalibrationScreenState();
}

class _SleepCalibrationScreenState extends State<SleepCalibrationScreen> {
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied — you can paste this into a message',
        style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
      backgroundColor: BMHColors.sSleep,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BMHRadius.full))));
  }

  @override
  Widget build(BuildContext context) {
    final report = _ble.lastSleepDebug;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 1),
      body: SafeArea(bottom: false, child: Column(children: [
        // ── Header ────────────────────────────────
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BMHEyebrow('Diagnostics'),
                Text('Sleep Calibration', style: BMHText.heading1),
              ])),
            if (report != null)
              BMHIconButton(
                onTap: () => _copy(report.toReport()),
                icon: const Icon(Icons.copy_rounded,
                  color: BMHColors.ink, size: 16)),
          ])),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // ── Instructions ────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BMHColors.cyanFaint,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.lineBright)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.science_outlined,
                        color: BMHColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      Text('How to use this screen',
                        style: BMHText.heading3.copyWith(
                          color: BMHColors.cyan)),
                    ]),
                    const SizedBox(height: 10),
                    _step(1, 'Wear the band overnight, then sync it.'),
                    _step(2, 'Open this screen. The raw numbers below are '
                             'exactly what the band sent — no processing.'),
                    _step(3, 'Open the JCVital app and note its deep, '
                             'light and awake times for the same night.'),
                    _step(4, 'Tap the copy icon above, then send both '
                             'together so the mapping can be locked in.'),
                  ])),

              const SizedBox(height: 18),

              if (report == null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    const Icon(Icons.bedtime_outlined,
                      color: BMHColors.inkMute, size: 32),
                    const SizedBox(height: 12),
                    Text('No sleep data yet',
                      style: BMHText.heading3.copyWith(
                        color: BMHColors.inkDim)),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        'Wear the band overnight and sync it, then come '
                        'back here.',
                        textAlign: TextAlign.center,
                        style: BMHText.bodySm.copyWith(
                          color: BMHColors.inkMute))),
                  ])),
              ] else ...[
                // ── Summary ───────────────────────
                Text('WHAT THE BAND SENT',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    _kv('Samples received', '${report.totalSamples}'),
                    _kv('Each sample covers', '${report.unitMin} minutes'),
                    _kv('Highest value seen', '${report.observedMax}'),
                    _kv('Reading it as',
                      report.encoding == SleepEncoding.ordinal
                        ? 'stage codes'
                        : 'movement counts',
                      highlight: true),
                  ])),

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BMHColors.bg3,
                    borderRadius: BorderRadius.circular(BMHRadius.md),
                    border: Border.all(color: BMHColors.line)),
                  child: Text(
                    report.encoding == SleepEncoding.ordinal
                      ? 'The highest value is ${report.observedMax}, which is '
                        'small. That means the band is sending stage codes '
                        '(each number already names a stage) rather than '
                        'movement amounts. The old code assumed movement '
                        'amounts, which is why almost everything was being '
                        'counted as deep sleep.'
                      : 'Values go up to ${report.observedMax}, a wide range. '
                        'That means the band is sending movement amounts, '
                        'which get grouped into stages by size.',
                    style: BMHText.bodySm.copyWith(
                      color: BMHColors.ink2, height: 1.45))),

                const SizedBox(height: 22),

                // ── Histogram ─────────────────────
                Text('EVERY VALUE, AND HOW OFTEN IT APPEARED',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),
                _histogram(report),

                const SizedBox(height: 22),

                // ── This app's result ─────────────
                Text('WHAT THIS APP CALCULATED',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    _stage('Deep',  report.result.deepMinutes,
                      report.result.deepPercent, BMHColors.sSleep),
                    _stage('Light', report.result.lightMinutes,
                      report.result.lightPercent, const Color(0xFF5bc4f5)),
                    _stage('Awake', report.result.awakeMinutes,
                      null, BMHColors.sCardio),
                    const Divider(height: 22, color: BMHColors.line),
                    _kv('Total asleep',
                      _fmt(report.result.asleepMinutes)),
                    _kv('Efficiency',
                      '${report.result.efficiency.toStringAsFixed(0)}%'),
                    _kv('REM', 'not reported by this band'),
                  ])),

                const SizedBox(height: 22),

                // ── Comparison prompt ─────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMHColors.sSleep.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: BMHColors.sSleep.withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Now compare with JCVital',
                        style: BMHText.heading3.copyWith(
                          color: BMHColors.sSleep)),
                      const SizedBox(height: 8),
                      Text(
                        'If JCVital shows different deep / light / awake '
                        'times for this same night, the numbers above tell '
                        'us exactly how to correct it. Tap copy at the top '
                        'and send it along with a JCVital screenshot.',
                        style: BMHText.bodySm.copyWith(
                          color: BMHColors.ink2, height: 1.45)),
                    ])),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () => _copy(report.toReport()),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: BMHColors.sSleep,
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_rounded,
                          color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Copy this report',
                          style: BMHText.labelLg.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                      ]))),
              ],

              const SizedBox(height: 120),
            ]))),
      ])),
    );
  }

  // ── small builders ───────────────────────────────────
  Widget _step(int n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18,
        margin: const EdgeInsets.only(top: 1),
        decoration: const BoxDecoration(
          color: BMHColors.cyan, shape: BoxShape.circle),
        child: Center(child: Text('$n',
          style: BMHText.monoSm.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BMHColors.bg0)))),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
        style: BMHText.bodySm.copyWith(
          color: BMHColors.ink2, height: 1.4))),
    ]));

  Widget _kv(String k, String v, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(k,
        style: BMHText.bodySm.copyWith(color: BMHColors.inkDim))),
      Text(v,
        style: BMHText.monoSm.copyWith(
          fontSize: 12,
          color: highlight ? BMHColors.cyan : BMHColors.ink,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
    ]));

  Widget _stage(String label, int minutes, double? pct, Color color) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          style: BMHText.bodySm.copyWith(color: BMHColors.ink2))),
        Text(_fmt(minutes),
          style: BMHText.monoSm.copyWith(fontSize: 12, color: color)),
        if (pct != null) ...[
          const SizedBox(width: 8),
          SizedBox(width: 44, child: Text('${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: BMHText.monoSm.copyWith(
              fontSize: 11, color: BMHColors.inkMute))),
        ],
      ]));

  Widget _histogram(SleepDebugReport r) {
    final keys = r.valueHistogram.keys.toList()..sort();
    final maxCount = r.valueHistogram.values.isEmpty
        ? 1
        : r.valueHistogram.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 42, child: Text('value $k',
                style: BMHText.monoSm.copyWith(
                  fontSize: 11, color: BMHColors.ink))),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(BMHRadius.full),
                child: LinearProgressIndicator(
                  value: r.valueHistogram[k]! / maxCount,
                  minHeight: 8,
                  backgroundColor: BMHColors.bg4,
                  valueColor: const AlwaysStoppedAnimation(
                    BMHColors.sSleep)))),
              const SizedBox(width: 10),
              SizedBox(width: 74, child: Text(
                '${r.valueHistogram[k]}× · '
                '${_fmt(r.valueHistogram[k]! * r.unitMin)}',
                textAlign: TextAlign.right,
                style: BMHText.monoSm.copyWith(
                  fontSize: 10, color: BMHColors.inkMute))),
            ])),
        ],
      ]));
  }

  static String _fmt(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${mm}m';
  }
}
