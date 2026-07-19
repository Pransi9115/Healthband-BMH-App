// ─────────────────────────────────────────────────────────
//  DIET — MICRONUTRIENT DASHBOARD
//  Vitamins · Minerals · Essential fats, all against RDA
// ─────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/diet/diet_models.dart';
import '../../core/diet/diet_service.dart';

class MicronutrientsScreen extends StatefulWidget {
  final DateTime day;
  const MicronutrientsScreen({super.key, required this.day});

  @override
  State<MicronutrientsScreen> createState() => _MicronutrientsScreenState();
}

class _MicronutrientsScreenState extends State<MicronutrientsScreen> {
  final _diet = DietService.instance;
  static const _accent = BMHColors.sMetabolic;

  @override
  void initState() {
    super.initState();
    _diet.addListener(_onDiet);
  }

  void _onDiet() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _diet.removeListener(_onDiet);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score   = _diet.microScore(widget.day);
    final totals  = _diet.microsFor(widget.day);
    final optimal = _diet.optimalCount(widget.day);
    final low     = _diet.lowCount(widget.day);

    List<Micronutrient> group(MicroGroup g) =>
        Micronutrient.all.where((m) => m.group == g).toList();

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -150, right: -110,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
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
                  const BMHEyebrow('Today'),
                  Text('Micronutrients', style: BMHText.heading1),
                ])),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── SCORE RING ──────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [_accent.withOpacity(0.12), BMHColors.bg3]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: _accent.withOpacity(0.35))),
                  child: Row(children: [
                    SizedBox(width: 92, height: 92, child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(width: 92, height: 92,
                          child: CircularProgressIndicator(
                            value: (score / 100).clamp(0.0, 1.0),
                            strokeWidth: 8,
                            backgroundColor: BMHColors.bg4,
                            valueColor: AlwaysStoppedAnimation(
                              _scoreColor(score)))),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${score.round()}%',
                              style: BMHText.displaySm.copyWith(
                                fontSize: 22, color: BMHColors.ink)),
                            Text('OPTIMAL',
                              style: BMHText.monoSm.copyWith(
                                fontSize: 8, letterSpacing: 1.2,
                                color: BMHColors.inkMute)),
                          ]),
                      ])),
                    const SizedBox(width: 18),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_headline(score), style: BMHText.heading2),
                        const SizedBox(height: 10),
                        Row(children: [
                          _Tag('$optimal optimal', BMHColors.sGut),
                          const SizedBox(width: 8),
                          _Tag('$low low', BMHColors.danger),
                        ]),
                      ])),
                  ])),

                const SizedBox(height: 24),

                _Section(
                  title: 'VITAMINS',
                  items: group(MicroGroup.vitamin),
                  totals: totals),
                const SizedBox(height: 22),
                _Section(
                  title: 'MINERALS',
                  items: group(MicroGroup.mineral),
                  totals: totals),
                const SizedBox(height: 22),
                _Section(
                  title: 'ESSENTIAL FATS',
                  items: group(MicroGroup.essentialFat),
                  totals: totals),

                const SizedBox(height: 20),

                // ── GUIDANCE ────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMHColors.cyanFaint,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.lineBright)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                        color: BMHColors.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Percentages are against general adult reference '
                        'intakes. Your own targets may differ — your care '
                        'team can adjust them from blood and DNA results.',
                        style: BMHText.bodySm.copyWith(
                          color: BMHColors.ink2, height: 1.45))),
                    ])),

                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  static Color _scoreColor(double s) {
    if (s >= 70) return BMHColors.sGut;
    if (s >= 50) return BMHColors.warn;
    return BMHColors.danger;
  }

  static String _headline(double s) {
    if (s >= 80) return 'Excellent coverage today';
    if (s >= 70) return 'On track today';
    if (s >= 50) return 'Some gaps to close';
    return 'Several nutrients running low';
  }
}

// ─────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Micronutrient> items;
  final Map<String, double> totals;

  const _Section({
    required this.title,
    required this.items,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: BMHText.monoSm.copyWith(
            fontSize: 10, letterSpacing: 1.6, color: BMHColors.inkDim)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: BMHColors.line),
              _Row(nutrient: items[i], got: totals[items[i].name] ?? 0),
            ],
          ])),
      ]);
  }
}

// ─────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final Micronutrient nutrient;
  final double got;

  const _Row({required this.nutrient, required this.got});

  double get _pct =>
      nutrient.rda <= 0 ? 0 : (got / nutrient.rda * 100);

  Color get _c {
    if (_pct >= 70) return BMHColors.sGut;
    if (_pct >= 50) return BMHColors.warn;
    return BMHColors.danger;
  }

  String get _amount {
    final v = got >= 10 ? got.toStringAsFixed(0) : got.toStringAsFixed(1);
    final tag = _pct < 50 ? ' · low' : '';
    return '$v ${nutrient.unit}$tag';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(nutrient.name,
            style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
          Text('${math.min(_pct, 999).round()}%',
            style: BMHText.monoSm.copyWith(fontSize: 11, color: _c)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(BMHRadius.full),
          child: LinearProgressIndicator(
            value: (_pct / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: BMHColors.bg4,
            valueColor: AlwaysStoppedAnimation(_c))),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: Text(_amount,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: BMHColors.inkMute))),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(BMHRadius.full),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text,
      style: BMHText.monoSm.copyWith(fontSize: 10, color: color)));
}
